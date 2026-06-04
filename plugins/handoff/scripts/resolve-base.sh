#!/usr/bin/env bash
# ============================================================================
# HANDOFF RESOLVE-BASE — pick the appropriate "base branch" for cache routing
# ============================================================================
# The specialist cache is keyed by <repo>@<base-branch>.md instead of by the
# session's literal current branch. This lets feature branches share a cache
# with their integration branch (e.g., feature/login reuses main's cache).
#
# Resolution algorithm:
#   1. Explicit HANDOFF_BASE_BRANCH env var wins.
#   2. If the current branch matches the base-branch pattern (main, master,
#      develop, or v<n>[.<m>[.<p>]]), use it as-is.
#   3. Otherwise enumerate refs (local + origin/) matching the same pattern,
#      filter to those that are ancestors of HEAD, pick the closest by
#      commit count.
#   4. If nothing qualifies, fall back to the current branch (today's behavior).
#
# Usage:
#   resolve-base.sh <cwd> <current-branch>
#
# Stdout: the resolved base-branch name (single line). Falls back to
# <current-branch> when no base can be determined.
# Exit:   0 always (best-effort; never block the caller).
# ============================================================================

set -uo pipefail

CWD="${1:-}"
CURRENT="${2:-}"

if [[ -z "$CWD" || -z "$CURRENT" ]]; then
    echo "usage: resolve-base.sh <cwd> <current-branch>" >&2
    exit 0
fi

# Explicit override always wins.
if [[ -n "${HANDOFF_BASE_BRANCH:-}" ]]; then
    echo "${HANDOFF_BASE_BRANCH}"
    exit 0
fi

is_base_pattern() {
    local b="$1"
    case "$b" in
        main|master|develop) return 0 ;;
    esac
    [[ "$b" =~ ^v[0-9]+(\.[0-9]+){0,2}$ ]] && return 0
    return 1
}

# Current branch is itself a base?
if is_base_pattern "$CURRENT"; then
    echo "$CURRENT"
    exit 0
fi

# Non-git or unreadable — fall back to current branch.
if ! git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
    echo "$CURRENT"
    exit 0
fi

# Enumerate candidate base refs from both local heads and origin tracking
# refs. Deduplicate by short name (e.g. v0.5 and origin/v0.5 → one entry).
declare -A seen=()
candidates=()
while IFS= read -r ref; do
    short="${ref#refs/heads/}"
    short="${short#refs/remotes/origin/}"
    if is_base_pattern "$short" && [[ -z "${seen[$short]:-}" ]]; then
        seen[$short]=1
        candidates+=("$short")
    fi
done < <(git -C "$CWD" for-each-ref --format='%(refname)' refs/heads/ refs/remotes/origin/ 2>/dev/null)

if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "$CURRENT"
    exit 0
fi

# Pick the candidate base whose commit distance from HEAD is smallest —
# i.e., the one the feature most recently branched from. We try BOTH the
# local ref and the origin tracking ref for each candidate and use whichever
# gives the smaller distance: local refs win when origin has diverged
# (common when a feature branch sat for a while while base advanced), and
# origin wins when local is stale or absent.
#
# We do NOT require the base to be an ancestor of HEAD — feature branches
# routinely diverge from their base in both directions (base accumulates
# merged work, feature accumulates its own commits). Distance alone is the
# more reliable signal of "closest fork point".
closest=""
closest_dist=""
for b in "${candidates[@]}"; do
    best_dist=""
    for ref_form in "${b}" "origin/${b}"; do
        git -C "$CWD" rev-parse --verify "$ref_form" >/dev/null 2>&1 || continue
        dist="$(git -C "$CWD" rev-list --count "${ref_form}..HEAD" 2>/dev/null || true)"
        [[ -z "$dist" ]] && continue
        if [[ -z "$best_dist" ]] || [[ "$dist" -lt "$best_dist" ]]; then
            best_dist="$dist"
        fi
    done
    [[ -z "$best_dist" ]] && continue
    if [[ -z "$closest_dist" ]] || [[ "$best_dist" -lt "$closest_dist" ]]; then
        closest="$b"
        closest_dist="$best_dist"
    fi
done

if [[ -n "$closest" ]]; then
    echo "$closest"
else
    echo "$CURRENT"
fi
