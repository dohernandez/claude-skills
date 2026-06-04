#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# HANDOFF UNREGISTER
# ============================================================================
# Best-effort cleanup at SessionEnd. We don't RELY on this firing (forced
# terminal closes / OOM kills won't run it) — every other session's
# register.sh GCs by PID, so stale rows self-clean. This just shortens the
# window where /handoff list shows ghosts of just-exited sessions.
# ============================================================================

readonly REGISTRY_DIR="${HOME}/.claude/handoff"
readonly REGISTRY="${REGISTRY_DIR}/.registry"
readonly SESSIONS_DIR="${REGISTRY_DIR}/.sessions"
readonly LOCKDIR="${REGISTRY_DIR}/.lock.d"

[[ -f "${REGISTRY}" ]] || exit 0

HOOK_INPUT="$(cat 2>/dev/null || echo '{}')"
SESSION_ID="$(printf '%s' "${HOOK_INPUT}" | jq -r '.session_id // empty' 2>/dev/null || echo '')"

# Best-effort lock — give up after 2s; cleanup is non-critical.
tries=0
while ! mkdir "${LOCKDIR}" 2>/dev/null; do
    if [[ -f "${LOCKDIR}/pid" ]]; then
        holder="$(cat "${LOCKDIR}/pid" 2>/dev/null || echo '')"
        if [[ -n "${holder}" ]] && ! kill -0 "${holder}" 2>/dev/null; then
            rm -rf "${LOCKDIR}"
            continue
        fi
    fi
    tries=$((tries + 1))
    [[ ${tries} -gt 20 ]] && exit 0
    sleep 0.1
done
echo "${PPID}" > "${LOCKDIR}/pid"
trap 'rm -rf "${LOCKDIR}" 2>/dev/null || true' EXIT

# Drop our row by SESSION_ID (preferred) or PID (fallback).
# session_id is the last field in both 5-col legacy and 7-col current
# schemas, so end-anchored grep works for both. PID-fallback checks both
# possible pid columns ($3 in legacy, $5 in current).
if [[ -n "${SESSION_ID}" ]]; then
    grep -v "|${SESSION_ID}\$" "${REGISTRY}" > "${REGISTRY}.tmp" 2>/dev/null || true
else
    awk -F'|' -v pid="${PPID}" '($3!=pid) && ($5!=pid)' "${REGISTRY}" > "${REGISTRY}.tmp" 2>/dev/null || true
fi
[[ -f "${REGISTRY}.tmp" ]] && mv "${REGISTRY}.tmp" "${REGISTRY}"

[[ -n "${SESSION_ID}" ]] && rm -f "${SESSIONS_DIR}/${SESSION_ID}.name" 2>/dev/null || true

exit 0
