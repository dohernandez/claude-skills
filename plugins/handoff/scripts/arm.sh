#!/usr/bin/env bash
# ============================================================================
# HANDOFF ARM — deliver a specialist prompt to another session
# ============================================================================
# Arms another live session as a domain specialist by delivering a prompt
# file via the handoff channel. The receiving agent is instructed to read
# the prompt, verify its own Monitor is alive, and acknowledge.
#
# When using the default specialist prompt, also routes a per-repo+branch
# context cache path to the receiver. The receiver applies the "Cache
# contract" in section 6 of the prompt to decide whether to use, supplement,
# or regenerate it — and writes its final synthesis back. Cache is disabled
# for custom prompts (--prompt) to avoid mixing specialist personas.
#
# This script handles step (a) — message delivery — only. The CALLING agent
# is also responsible for step (b): verifying its OWN Monitor is alive after
# arming, so it can receive the acknowledgment and follow-up traffic. The
# Monitor tool can only be invoked from inside a Claude Code agent context;
# a shell script cannot arm it on the caller's behalf.
#
# Usage:
#   arm.sh                                   # SELF-ARM (default) — current session
#   arm.sh --to <name>                       # arm another session explicitly
#   arm.sh <name>                            # arm another session (positional form)
#   arm.sh [target] --prompt <path>          # custom prompt, cache disabled
#   arm.sh [target] --no-cache               # default prompt, cache disabled
#   arm.sh [target] --rebuild-cache          # default prompt, ignore existing cache
#
# Default behavior: if neither --to nor a positional recipient is given, the
# recipient is auto-detected from the caller's PPID chain via the handoff
# registry (same logic as send.sh). This makes "self-arm me as a specialist
# on the current repo" a no-argument operation.
#
# Role lookup honors the layered config (project > global); overlay lenses
# resolve project > global > shipped library. See roles-lib.sh.
#
# Default prompt: <plugin>/specialist-prompt.md
# Cache path:     ~/.claude/handoff/specialist-cache/<repo-slug>@<branch-slug>.md
#                 (org/repo and branch slashes become "--" in the filename)
#
# Exit codes:
#   0 — message delivered
#   1 — usage error (including: self-arm requested but caller not in registry)
#   2 — recipient not found in live registry (propagated from send.sh)
#   3 — inbox write failed (propagated from send.sh)
#   4 — prompt file not found or not readable
# ============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/roles-lib.sh"

readonly DEFAULT_PROMPT="${PLUGIN_ROOT}/specialist-prompt.md"
readonly SEND_SCRIPT="${SCRIPT_DIR}/send.sh"
readonly REGISTRY="${HOME}/.claude/handoff/.registry"
readonly CACHE_DIR="${HOME}/.claude/handoff/specialist-cache"

usage() {
    cat >&2 <<USAGE
usage:
  arm.sh                              # self-arm the current session
  arm.sh --to <name>                  # arm another session (explicit flag)
  arm.sh <name>                       # arm another session (positional)
  arm.sh [target] --prompt <path>     # custom prompt (caching disabled)
  arm.sh [target] --no-cache          # default prompt, skip cache routing
  arm.sh [target] --rebuild-cache     # ignore existing cache, force fresh write

Default prompt: ${DEFAULT_PROMPT}
Cache dir:      ${CACHE_DIR}
List live recipients with /handoff list.
USAGE
}

RECIPIENT=""
RECIPIENT_VIA_TO=""
PROMPT_PATH="${DEFAULT_PROMPT}"
USE_CACHE="true"
REBUILD_CACHE="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --to)
            [[ $# -ge 2 ]] || { echo "ERROR: --to requires a recipient name" >&2; usage; exit 1; }
            RECIPIENT_VIA_TO="$2"
            shift 2
            ;;
        --to=*)
            RECIPIENT_VIA_TO="${1#--to=}"
            shift
            ;;
        --prompt)
            [[ $# -ge 2 ]] || { echo "ERROR: --prompt requires a path" >&2; usage; exit 1; }
            PROMPT_PATH="$2"
            shift 2
            ;;
        --prompt=*)
            PROMPT_PATH="${1#--prompt=}"
            shift
            ;;
        --no-cache)
            USE_CACHE="false"
            shift
            ;;
        --rebuild-cache)
            REBUILD_CACHE="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --*)
            echo "ERROR: unknown flag: $1" >&2
            usage
            exit 1
            ;;
        *)
            if [[ -z "$RECIPIENT" ]]; then
                RECIPIENT="$1"
            else
                echo "ERROR: unexpected positional arg: $1" >&2
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Reconcile positional vs --to forms.
if [[ -n "$RECIPIENT" && -n "$RECIPIENT_VIA_TO" && "$RECIPIENT" != "$RECIPIENT_VIA_TO" ]]; then
    echo "ERROR: conflicting recipients: positional '${RECIPIENT}' vs --to '${RECIPIENT_VIA_TO}'" >&2
    exit 1
fi
if [[ -z "$RECIPIENT" ]]; then
    RECIPIENT="$RECIPIENT_VIA_TO"
fi

# If still empty, self-arm: derive the caller's name from the registry by
# walking up the parent process chain (same approach send.sh uses to derive
# its sender). The first ancestor PID with a registry row is "us".
if [[ -z "$RECIPIENT" ]]; then
    pid=$$
    for _ in 1 2 3 4 5; do
        pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
        [[ -z "$pid" || "$pid" == "0" || "$pid" == "1" ]] && break
        RECIPIENT="$(awk -F'|' -v p="$pid" '($5==p || $3==p) {print $1; exit}' "$REGISTRY" 2>/dev/null || true)"
        [[ -n "$RECIPIENT" ]] && break
    done
    if [[ -z "$RECIPIENT" ]]; then
        echo "ERROR: self-arm requested but caller is not in the handoff registry." >&2
        echo "       Pass an explicit recipient with --to <name> or as a positional arg." >&2
        echo "       List live sessions: /handoff list" >&2
        exit 1
    fi
    SELF_ARM="true"
else
    SELF_ARM="false"
fi

# Resolve prompt path to absolute. Receiver runs in a different cwd, so a
# relative path would be ambiguous on their side.
if [[ "${PROMPT_PATH:0:1}" != "/" ]]; then
    PROMPT_PATH="$(pwd)/${PROMPT_PATH}"
fi

if [[ ! -r "$PROMPT_PATH" ]]; then
    echo "ERROR: prompt file not readable: ${PROMPT_PATH}" >&2
    exit 4
fi

# ============================================================================
# Look up recipient's repo + branch + cwd from the registry. Used by role
# resolution (roles.yaml mapping), base-branch resolution (cache anchoring),
# and cache routing.
# ============================================================================
RECIPIENT_REPO="$(awk -F'|' -v r="$RECIPIENT" '$1==r && NF>=7 {print $2; exit}' "$REGISTRY" 2>/dev/null || true)"
RECIPIENT_BRANCH="$(awk -F'|' -v r="$RECIPIENT" '$1==r && NF>=7 {print $3; exit}' "$REGISTRY" 2>/dev/null || true)"
RECIPIENT_CWD="$(awk -F'|' -v r="$RECIPIENT" '$1==r && NF>=7 {print $4; exit}' "$REGISTRY" 2>/dev/null || true)"

# Resolve the recipient's anchor branch — usually a base/integration branch
# (main, v0.5, etc.) shared across feature branches. Feature-branch agents
# load the base cache, supplement via diff, and write back. Convention-based
# (main/master/develop or v<n>[.<m>[.<p>]]); override with HANDOFF_BASE_BRANCH.
ANCHOR_BRANCH=""
if [[ -n "$RECIPIENT_CWD" && -n "$RECIPIENT_BRANCH" && "$RECIPIENT_BRANCH" != "-" ]]; then
    ANCHOR_BRANCH="$("${SCRIPT_DIR}/resolve-base.sh" "$RECIPIENT_CWD" "$RECIPIENT_BRANCH" 2>/dev/null || true)"
fi
[[ -z "$ANCHOR_BRANCH" ]] && ANCHOR_BRANCH="$RECIPIENT_BRANCH"

# ============================================================================
# Resolve role overlay from the layered config. The recipient's <org>/<repo>
# is looked up across tiers (project > global); the spec ("primary[+secondary
# ...]") splits on "+". Primary picks the overlay lens; secondaries are
# mentioned in the arming message body so the receiver knows which other
# tools/languages apply (without loading every secondary's prompt up-front).
#
# Custom --prompt always wins (no role lookup). Unmapped repos fall back to
# the default specialist-prompt.md alone and emit a stderr warning.
# ============================================================================
ROLE_OVERLAY_PATH=""
SECONDARY_MENTIONS=""  # comma-separated for the message body

if [[ "$PROMPT_PATH" == "$DEFAULT_PROMPT" && -n "$RECIPIENT_REPO" && "$RECIPIENT_REPO" != "-" ]]; then
    ROLE_MATCH="$(handoff_lookup_role "$RECIPIENT_CWD" "$RECIPIENT_REPO")"
    if [[ -n "$ROLE_MATCH" ]]; then
        ROLE_SPEC="${ROLE_MATCH%%$'\t'*}"
        ROLE_SRC="${ROLE_MATCH#*$'\t'}"
        IFS='+' read -ra ROLE_PARTS <<< "$ROLE_SPEC"
        PRIMARY="${ROLE_PARTS[0]}"
        ROLE_OVERLAY_PATH="$(handoff_resolve_lens "$RECIPIENT_CWD" "$PRIMARY")"
        if [[ -z "$ROLE_OVERLAY_PATH" ]]; then
            echo "[arm] role mapping found ('${PRIMARY}' via ${ROLE_SRC}) but no ${PRIMARY}.md lens in project/global/shipped — using default prompt only" >&2
        fi
        # Format secondaries: append " (see <file>)" if a matching lens exists.
        for (( i=1; i<${#ROLE_PARTS[@]}; i++ )); do
            sec="${ROLE_PARTS[i]}"
            [[ -z "$sec" ]] && continue
            sec_lens="$(handoff_resolve_lens "$RECIPIENT_CWD" "$sec")"
            if [[ -n "$sec_lens" ]]; then
                entry="${sec} (see ${sec_lens})"
            else
                entry="${sec}"
            fi
            if [[ -z "$SECONDARY_MENTIONS" ]]; then
                SECONDARY_MENTIONS="${entry}"
            else
                SECONDARY_MENTIONS="${SECONDARY_MENTIONS}, ${entry}"
            fi
        done
    else
        echo "[arm] no role mapping for ${RECIPIENT_REPO} (project/global roles.yaml) — using default prompt only. Add one with /handoff role set." >&2
    fi
fi

# ============================================================================
# Resolve cache path. Cache is only routed when:
#   - default prompt is in use (custom prompts → no cache, different personas)
#   - --no-cache wasn't passed
#   - recipient's registry row has real repo + branch values (not "-")
# ============================================================================
CACHE_PATH=""
CACHE_DISABLED_REASON=""

if [[ "$PROMPT_PATH" != "$DEFAULT_PROMPT" ]]; then
    CACHE_DISABLED_REASON="custom prompt"
elif [[ "$USE_CACHE" != "true" ]]; then
    CACHE_DISABLED_REASON="--no-cache flag"
elif [[ -z "$RECIPIENT_REPO" || "$RECIPIENT_REPO" == "-" ]]; then
    CACHE_DISABLED_REASON="recipient has no repo identity (non-git or legacy registry row)"
elif [[ -z "$ANCHOR_BRANCH" || "$ANCHOR_BRANCH" == "-" ]]; then
    CACHE_DISABLED_REASON="recipient has no branch identity"
else
    repo_slug="${RECIPIENT_REPO//\//--}"
    branch_slug="${ANCHOR_BRANCH//\//--}"
    CACHE_PATH="${CACHE_DIR}/${repo_slug}@${branch_slug}.md"
    mkdir -p "${CACHE_DIR}"
fi

# ============================================================================
# Build arming message and pipe to send.sh for envelope + delivery.
# ============================================================================
if [[ "$SELF_ARM" == "true" ]]; then
    echo "[arm] self-arm: ${RECIPIENT}" >&2
fi
if [[ -n "$ROLE_OVERLAY_PATH" ]]; then
    if [[ -n "$SECONDARY_MENTIONS" ]]; then
        echo "[arm] role: $(basename "${ROLE_OVERLAY_PATH}" .md), also: ${SECONDARY_MENTIONS}" >&2
    else
        echo "[arm] role: $(basename "${ROLE_OVERLAY_PATH}" .md)" >&2
    fi
fi
{
    if [[ -n "$ROLE_OVERLAY_PATH" ]]; then
        cat <<MSG
You are being armed as a domain specialist for this session.

Read these two prompt files in order, then operate under them for the rest of the session:

1. Base specialist contract (principles, discovery sequence, answer format, NOT-to-do, cache contract):
   ${PROMPT_PATH}

2. Role overlay (apply the base through this lens — identity, role-specific domain focus, role-specific don'ts):
   ${ROLE_OVERLAY_PATH}
MSG
        if [[ -n "$SECONDARY_MENTIONS" ]]; then
            cat <<MSG

This repo also makes use of: ${SECONDARY_MENTIONS}. Familiarize yourself with these during Step 1 (Orient). For items with a (see <file>) reference, load that role's prompt only if a question pushes you into that area.
MSG
        fi
    else
        cat <<MSG
You are being armed as a domain specialist for this session.

Read this prompt file and operate under it for the rest of the session:
  ${PROMPT_PATH}
MSG
    fi

    if [[ -n "$CACHE_PATH" ]]; then
        if [[ "$REBUILD_CACHE" == "true" ]]; then
            cat <<MSG

Repository context cache: ${CACHE_PATH}
Anchored to base branch: ${ANCHOR_BRANCH} (your current branch may differ; the cache is shared across feature branches off this base)
REBUILD requested — ignore any existing cache content. Run full discovery, then write a fresh synthesis to this path before acknowledging. When writing, preserve \`anchor_branch: ${ANCHOR_BRANCH}\` in the frontmatter.
MSG
        else
            cat <<MSG

Repository context cache: ${CACHE_PATH}
Anchored to base branch: ${ANCHOR_BRANCH} (your current branch may differ; the cache is shared across feature branches off this base)
If this file exists, treat it as a prior agent's mental model of this repo. Apply the Cache contract (§6 of the base prompt; schema 4). Key checks for a feature-branch reader: BOTH \`<cache.git_rev>..${ANCHOR_BRANCH}\` (anchor-advance: PRs merged into the base since the cache was written) AND \`${ANCHOR_BRANCH}..HEAD\` (your feature delta) must be hot-file-clean to use the cache as foundation. When you write, preserve \`anchor_branch: ${ANCHOR_BRANCH}\` and set \`git_rev\` to the anchor tip (\`git rev-parse origin/${ANCHOR_BRANCH}\` or local \`${ANCHOR_BRANCH}\`), NOT your own HEAD.
MSG
        fi
    fi

    cat <<MSG

After reading the prompt(s):
1. Verify your own inbox Monitor is alive. If the heartbeat is missing or stale, run /handoff monitor to re-arm.
2. Reply via send.sh acknowledging you are ready, naming the prompt file(s) you loaded, and your cache decision (used | supplemented | regenerated | none).

Do not summarize the prompts back — just confirm load + Monitor status + cache decision.
MSG
} | "${SEND_SCRIPT}" "${RECIPIENT}"

if [[ -z "$CACHE_PATH" && -n "$CACHE_DISABLED_REASON" ]]; then
    echo "[arm] cache disabled: ${CACHE_DISABLED_REASON}" >&2
fi
