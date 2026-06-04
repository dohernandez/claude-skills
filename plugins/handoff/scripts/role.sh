#!/usr/bin/env bash
# ============================================================================
# HANDOFF ROLE — manage the layered repo→role map
# ============================================================================
# Ergonomic front-end for the three role tiers (see roles-lib.sh):
#   GLOBAL   ~/.claude/handoff/roles.yaml            (your personal default)
#   PROJECT  <repo-root>/.claude/handoff/roles.yaml  (committed, team-shared)
#
# Subcommands:
#   role.sh show [<org/repo>]            # resolved role for a repo (+ source tier)
#   role.sh list                         # every mapping across tiers, annotated
#   role.sh set <spec> [--global|--repo] [--for <org/repo>]
#   role.sh unset <org/repo> [--global|--repo]
#   role.sh edit [--global|--repo]       # open the tier file in $EDITOR
#   role.sh init [--global|--repo]       # create the tier file from the template
#
# <spec> is "primary[+secondary[+...]]", e.g. "golang+gha". The repo key
# defaults to the current repo (auto-detected); override with --for.
# When no tier flag is given, writes go to GLOBAL (safe; never mutates the
# repo working tree). Pass --repo to write the committable project file.
#
# Exit codes: 0 ok, 1 usage error, 2 nothing to show.
# ============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
readonly TEMPLATE="${PLUGIN_ROOT}/roles.yaml.example"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/roles-lib.sh"

CWD="$(pwd)"

usage() {
    cat >&2 <<USAGE
usage:
  role.sh show [<org/repo>]                       resolved role + source tier
  role.sh list                                    all mappings across tiers
  role.sh set <spec> [--global|--repo] [--for <org/repo>]
  role.sh unset <org/repo> [--global|--repo]
  role.sh edit [--global|--repo]                  open tier file in \$EDITOR
  role.sh init [--global|--repo]                  create tier file from template

Tiers: --global (~/.claude/handoff/roles.yaml, default for writes)
       --repo   (<repo-root>/.claude/handoff/roles.yaml, committable)
USAGE
}

# Lens existence check (any tier). Echoes "ok" or "".
lens_exists() {
    local name="$1"
    [[ -n "$(handoff_resolve_lens "$CWD" "$name")" ]] && echo "ok" || echo ""
}

# Resolve the file path for a tier, erroring if --repo outside a git repo.
tier_file() {
    local tier="$1" f
    f="$(handoff_roles_file_for_tier "$tier" "$CWD")"
    if [[ "$tier" == "project" && -z "$f" ]]; then
        echo "ERROR: --repo requires a git repository (none detected at ${CWD})" >&2
        exit 1
    fi
    printf '%s' "$f"
}

# Ensure a roles.yaml exists at <path>, seeding a minimal header if absent.
ensure_file() {
    local f="$1"
    [[ -f "$f" ]] && return 0
    mkdir -p "$(dirname "$f")"
    if [[ -r "$TEMPLATE" ]]; then
        cp "$TEMPLATE" "$f"
    else
        cat > "$f" <<'HDR'
# handoff role map — <org>/<repo>: <primary>[+<secondary>...]
HDR
    fi
}

# Upsert "key: spec" into file <f>, preserving comments. Replaces an existing
# uncommented "key:" line in place; otherwise appends.
upsert_mapping() {
    local f="$1" key="$2" spec="$3" tmp
    ensure_file "$f"
    if grep -qE "^[[:space:]]*${key//\//\\/}[[:space:]]*:" "$f" 2>/dev/null; then
        tmp="$(mktemp)"
        awk -v k="$key" -v s="$spec" '
            { line=$0; t=line; sub(/^[[:space:]]+/,"",t)
              if (t ~ "^" k "[[:space:]]*:") { print k ": " s } else { print line } }
        ' "$f" > "$tmp" && mv "$tmp" "$f"
    else
        printf '%s: %s\n' "$key" "$spec" >> "$f"
    fi
}

# Remove an uncommented "key:" line from file <f>.
remove_mapping() {
    local f="$1" key="$2" tmp
    [[ -f "$f" ]] || return 0
    tmp="$(mktemp)"
    awk -v k="$key" '
        { line=$0; t=line; sub(/^[[:space:]]+/,"",t)
          if (t ~ "^" k "[[:space:]]*:") next; print line }
    ' "$f" > "$tmp" && mv "$tmp" "$f"
}

# Print every uncommented mapping in <f> as "key<TAB>spec".
dump_mappings() {
    local f="$1"
    [[ -r "$f" ]] || return 0
    awk -F': *' '
        { line=$0; sub(/^[[:space:]]+/,"",line)
          if (line ~ /^#/ || line=="") next
          if (NF>=2) { k=$1; sub(/[[:space:]]+$/,"",k); print k "\t" $2 } }
    ' "$f"
}

CMD="${1:-}"; [[ $# -gt 0 ]] && shift || true

case "$CMD" in
    show)
        REPO="${1:-$(handoff_detect_repo "$CWD")}"
        if [[ -z "$REPO" || "$REPO" == "-" ]]; then
            echo "ERROR: no repo given and current dir is not a git repo" >&2
            exit 1
        fi
        MATCH="$(handoff_lookup_role "$CWD" "$REPO")"
        if [[ -z "$MATCH" ]]; then
            echo "${REPO}: (no mapping — generic specialist prompt)"
            exit 2
        fi
        SPEC="${MATCH%%$'\t'*}"
        SRC="${MATCH#*$'\t'}"
        TIER="global"; [[ "$SRC" == *"/.claude/handoff/roles.yaml" && "$SRC" != "${HOME}/.claude/handoff/roles.yaml" ]] && TIER="project"
        [[ -n "${HANDOFF_ROLES_YAML:-}" && "$SRC" == "${HANDOFF_ROLES_YAML}" ]] && TIER="env"
        echo "${REPO}: ${SPEC}  (from: ${TIER} — ${SRC})"
        ;;

    list)
        printf '%-40s %-24s %s\n' "REPO" "ROLE" "TIER"
        # global then project; project entries override (printed, marked).
        GLOBAL_F="$(handoff_roles_file_for_tier global "$CWD")"
        PROJECT_F="$(handoff_roles_file_for_tier project "$CWD")"
        declare -A proj_keys=()
        if [[ -n "$PROJECT_F" && -r "$PROJECT_F" ]]; then
            while IFS=$'\t' read -r k s; do
                [[ -z "$k" ]] && continue
                proj_keys["$k"]=1
                printf '%-40s %-24s %s\n' "$k" "$s" "project"
            done < <(dump_mappings "$PROJECT_F")
        fi
        if [[ -r "$GLOBAL_F" ]]; then
            while IFS=$'\t' read -r k s; do
                [[ -z "$k" ]] && continue
                if [[ -n "${proj_keys[$k]:-}" ]]; then
                    printf '%-40s %-24s %s\n' "$k" "$s" "global (overridden by project)"
                else
                    printf '%-40s %-24s %s\n' "$k" "$s" "global"
                fi
            done < <(dump_mappings "$GLOBAL_F")
        fi
        ;;

    set)
        [[ $# -ge 1 ]] || { echo "ERROR: set requires a <spec>" >&2; usage; exit 1; }
        SPEC=""; TIER="global"; FOR_REPO=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --global) TIER="global"; shift ;;
                --repo|--project) TIER="project"; shift ;;
                --for) [[ $# -ge 2 ]] || { echo "ERROR: --for needs a repo" >&2; exit 1; }; FOR_REPO="$2"; shift 2 ;;
                --for=*) FOR_REPO="${1#--for=}"; shift ;;
                -*) echo "ERROR: unknown flag: $1" >&2; usage; exit 1 ;;
                *) [[ -z "$SPEC" ]] && SPEC="$1" || { echo "ERROR: unexpected arg: $1" >&2; exit 1; }; shift ;;
            esac
        done
        [[ -n "$SPEC" ]] || { echo "ERROR: set requires a <spec>" >&2; exit 1; }
        KEY="${FOR_REPO:-$(handoff_detect_repo "$CWD")}"
        if [[ -z "$KEY" || "$KEY" == "-" ]]; then
            echo "ERROR: could not determine repo key — pass --for <org/repo>" >&2
            exit 1
        fi
        PRIMARY="${SPEC%%+*}"
        [[ -z "$(lens_exists "$PRIMARY")" ]] && \
            echo "[role] warning: no '${PRIMARY}.md' lens found (project/global/shipped). The mapping is saved; the generic prompt will be used until a lens exists." >&2
        F="$(tier_file "$TIER")"
        upsert_mapping "$F" "$KEY" "$SPEC"
        echo "set ${KEY}: ${SPEC}  ->  ${F} (${TIER})"
        [[ "$TIER" == "project" ]] && echo "note: ${F} is committable — commit it to share this role with your team."
        ;;

    unset)
        [[ $# -ge 1 ]] || { echo "ERROR: unset requires <org/repo>" >&2; usage; exit 1; }
        KEY=""; TIER="global"
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --global) TIER="global"; shift ;;
                --repo|--project) TIER="project"; shift ;;
                -*) echo "ERROR: unknown flag: $1" >&2; usage; exit 1 ;;
                *) [[ -z "$KEY" ]] && KEY="$1" || { echo "ERROR: unexpected arg: $1" >&2; exit 1; }; shift ;;
            esac
        done
        [[ -n "$KEY" ]] || { echo "ERROR: unset requires <org/repo>" >&2; exit 1; }
        F="$(tier_file "$TIER")"
        remove_mapping "$F" "$KEY"
        echo "unset ${KEY}  ->  ${F} (${TIER})"
        ;;

    edit)
        TIER="global"
        case "${1:-}" in
            --repo|--project) TIER="project" ;;
            --global|"") TIER="global" ;;
            *) echo "ERROR: unknown flag: $1" >&2; usage; exit 1 ;;
        esac
        F="$(tier_file "$TIER")"
        ensure_file "$F"
        "${EDITOR:-vi}" "$F"
        ;;

    init)
        TIER="global"
        case "${1:-}" in
            --repo|--project) TIER="project" ;;
            --global|"") TIER="global" ;;
            *) echo "ERROR: unknown flag: $1" >&2; usage; exit 1 ;;
        esac
        F="$(tier_file "$TIER")"
        if [[ -f "$F" ]]; then
            echo "exists: ${F} (left untouched)"
        else
            ensure_file "$F"
            echo "created: ${F} (${TIER}) from template"
        fi
        ;;

    -h|--help|"")
        usage
        [[ -z "$CMD" ]] && exit 1 || exit 0
        ;;
    *)
        echo "ERROR: unknown subcommand: ${CMD}" >&2
        usage
        exit 1
        ;;
esac
