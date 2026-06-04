#!/usr/bin/env bash
# ============================================================================
# HANDOFF ROLES-LIB — layered role/lens resolution
# ============================================================================
# Sourced by register.sh, arm.sh, and role.sh. Implements the three-tier
# precedence for mapping a repo to a specialist role:
#
#   1. $HANDOFF_ROLES_YAML        — explicit env override (one file, wholesale)
#   2. <repo-root>/.claude/handoff/roles.yaml   — PROJECT tier (committed,
#                                                  shared with the whole team)
#   3. ~/.claude/handoff/roles.yaml             — GLOBAL tier (your personal
#                                                  default across all repos)
#
# Resolution is first-match-wins per repo lookup (NOT a deep merge): the
# project file's entry for repo R overrides the global file's entry for R.
#
# Role-overlay ".md" lenses layer the same way, with a shipped library as the
# final fallback:
#   <repo-root>/.claude/handoff/roles/<name>.md   (project custom lens)
#   ~/.claude/handoff/roles/<name>.md             (global custom lens)
#   ${PLUGIN_ROOT}/roles/<name>.md                (shipped library lens)
#
# Callers that use handoff_resolve_lens MUST export/set PLUGIN_ROOT first
# (the plugin's install dir; ${CLAUDE_PLUGIN_ROOT} or a BASH_SOURCE fallback).
#
# All functions are best-effort and return 0 even on miss, so they are safe
# under `set -euo pipefail`.
# ============================================================================

# State dir for the global tier.
handoff_state_dir() { printf '%s' "${HOME}/.claude/handoff"; }

# Git work-tree root for a cwd, or empty for non-git.
# Args: <cwd>
handoff_repo_root() {
    local cwd="${1:-}"
    [[ -z "$cwd" ]] && return 0
    git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true
}

# Canonical <org>/<repo> identity for a cwd (stable across worktrees).
# $HANDOFF_REPO overrides. Falls back to "-" for non-git directories.
# Args: <cwd>
handoff_detect_repo() {
    local cwd="${1:-}" remote common repo_dir
    if [[ -n "${HANDOFF_REPO:-}" ]]; then
        printf '%s' "${HANDOFF_REPO}"; return 0
    fi
    [[ -z "$cwd" ]] && { printf '%s' "-"; return 0; }
    remote="$(git -C "$cwd" config --get remote.origin.url 2>/dev/null || true)"
    if [[ -n "$remote" ]]; then
        printf '%s' "$remote" | sed -E 's#^(https?://[^/]+/|git@[^:]+:)##; s#\.git$##'
        return 0
    fi
    common="$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null || true)"
    if [[ -n "$common" ]]; then
        repo_dir="$(cd "$cwd" && cd "${common}/.." 2>/dev/null && pwd || true)"
        [[ -n "$repo_dir" ]] && { basename "$repo_dir"; return 0; }
    fi
    printf '%s' "-"
}

# Echo candidate roles.yaml files, highest precedence first, one per line.
# Args: <cwd>
handoff_roles_files() {
    local cwd="${1:-}" top
    [[ -n "${HANDOFF_ROLES_YAML:-}" ]] && printf '%s\n' "${HANDOFF_ROLES_YAML}"
    top="$(handoff_repo_root "$cwd")"
    [[ -n "$top" ]] && printf '%s\n' "${top}/.claude/handoff/roles.yaml"
    printf '%s\n' "${HOME}/.claude/handoff/roles.yaml"
}

# Resolve the absolute path of the roles.yaml file for a given tier.
# Args: <tier: global|project> <cwd>
# Echoes the path (always for global; for project only when in a git repo).
handoff_roles_file_for_tier() {
    local tier="${1:-global}" cwd="${2:-}" top
    case "$tier" in
        project)
            top="$(handoff_repo_root "$cwd")"
            [[ -n "$top" ]] && printf '%s' "${top}/.claude/handoff/roles.yaml"
            ;;
        *)
            printf '%s' "${HOME}/.claude/handoff/roles.yaml"
            ;;
    esac
}

# Look up a repo's role spec across tiers. On first match echoes:
#   <spec><TAB><source-file>
# Nothing if unmapped.
# Args: <cwd> <repo>
handoff_lookup_role() {
    local cwd="${1:-}" repo="${2:-}" f spec
    [[ -z "$repo" || "$repo" == "-" ]] && return 0
    while IFS= read -r f; do
        [[ -r "$f" ]] || continue
        spec="$(awk -F': *' -v r="$repo" '$1==r {print $2; exit}' "$f" 2>/dev/null || true)"
        if [[ -n "$spec" ]]; then
            printf '%s\t%s\n' "$spec" "$f"
            return 0
        fi
    done < <(handoff_roles_files "$cwd")
    return 0
}

# Resolve a lens ".md" across tiers. Echoes the path or nothing.
# Args: <cwd> <name>
handoff_resolve_lens() {
    local cwd="${1:-}" name="${2:-}" top
    [[ -z "$name" ]] && return 0
    top="$(handoff_repo_root "$cwd")"
    if [[ -n "$top" && -r "${top}/.claude/handoff/roles/${name}.md" ]]; then
        printf '%s\n' "${top}/.claude/handoff/roles/${name}.md"; return 0
    fi
    if [[ -r "${HOME}/.claude/handoff/roles/${name}.md" ]]; then
        printf '%s\n' "${HOME}/.claude/handoff/roles/${name}.md"; return 0
    fi
    if [[ -n "${PLUGIN_ROOT:-}" && -r "${PLUGIN_ROOT}/roles/${name}.md" ]]; then
        printf '%s\n' "${PLUGIN_ROOT}/roles/${name}.md"; return 0
    fi
    return 0
}
