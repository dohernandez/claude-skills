#!/usr/bin/env bash
# ============================================================================
# HANDOFF GC — reap orphan Monitor processes for a given inbox
# ============================================================================
# When a Claude session goes through /clear or /compact, the SessionStart
# hook fires with a new session_id but the Monitor child process keeps
# running with the old session_id baked into its HEARTBEAT path. The orphan
# continues to race the live Monitor on the same inbox file (atomic mv), and
# every message it wins consumes is silently lost — its stdout is no longer
# wired to any live Claude conversation.
#
# This script finds and kills any Monitor process polling the named inbox
# whose heartbeat path's session_id differs from the current session_id.
# The current session's own Monitor (if any) is spared by exact match on
# the heartbeat path. Stale heartbeat files for the reaped sessions are
# removed so the directory doesn't accumulate cruft.
#
# Usage:
#   gc.sh <inbox-name> <current-session-id>
#
# Stderr: diagnostics about what was killed.
# Exit:   0 always — best-effort cleanup; never block the caller.
# ============================================================================

set -uo pipefail

INBOX_NAME="${1:-}"
CURRENT_SID="${2:-}"

if [[ -z "$INBOX_NAME" || -z "$CURRENT_SID" ]]; then
    echo "usage: gc.sh <inbox-name> <current-session-id>" >&2
    exit 0
fi

readonly REGISTRY_DIR="${HOME}/.claude/handoff"
readonly SESSIONS_DIR="${REGISTRY_DIR}/.sessions"
readonly INBOX_PATH="${REGISTRY_DIR}/${INBOX_NAME}.signal"
readonly CURRENT_HEARTBEAT="${SESSIONS_DIR}/${CURRENT_SID}.monitor.alive"

# Build the exact substrings the Monitor command line contains. Matching the
# fully-qualified INBOX="..." and HEARTBEAT="..." strings avoids prefix
# collisions (e.g. genlayer-node vs genlayer-node-2 differ in the trailing
# .signal suffix).
readonly INBOX_NEEDLE="INBOX=\"${INBOX_PATH}\""
readonly SPARE_NEEDLE="HEARTBEAT=\"${CURRENT_HEARTBEAT}\""

# ps -eo pid,command — find processes whose command line contains our inbox
# but NOT the current session's heartbeat (so we spare the live Monitor).
# awk's index() returns 0 when not found, >0 when found.
candidates="$(
    ps -eo pid=,command= 2>/dev/null | awk \
        -v inbox="${INBOX_NEEDLE}" \
        -v spare="${SPARE_NEEDLE}" '
        index($0, inbox) > 0 && index($0, spare) == 0 { print $1 }
    '
)"

killed=0
while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue

    # Extract the orphan's session_id from its command line so we can also
    # clean up its stale heartbeat file. The HEARTBEAT="..." substring sits
    # inline in the eval'd Monitor body.
    orphan_sid="$(
        ps -p "$pid" -o command= 2>/dev/null | \
        sed -nE 's|.*HEARTBEAT="[^"]*/\.sessions/([^"]+)\.monitor\.alive".*|\1|p'
    )"

    if kill "$pid" 2>/dev/null; then
        echo "[handoff/gc] reaped orphan Monitor pid=${pid} inbox=${INBOX_NAME} sid=${orphan_sid:-unknown}" >&2
        killed=$((killed + 1))
        if [[ -n "${orphan_sid:-}" ]]; then
            rm -f "${SESSIONS_DIR}/${orphan_sid}.monitor.alive" 2>/dev/null || true
        fi
    fi
done <<< "${candidates}"

if [[ ${killed} -gt 0 ]]; then
    echo "[handoff/gc] reaped ${killed} orphan(s) for inbox=${INBOX_NAME}" >&2
fi

exit 0
