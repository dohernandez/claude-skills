#!/usr/bin/env bash
# Read by Claude Code statusLine. Stdin is the statusLine JSON (session_id,
# cwd, model, ...). Stdout is the rendered statusline string.
#
# Output format:
#   [handoff: <name>]              — registered AND Monitor heartbeat is fresh
#   [handoff: <name> ⚠ no monitor]  — registered but Monitor missing/stale
#   (empty)                        — no marker (session not registered yet)
#
# The "no monitor" state means another Claude session can write to your inbox
# but you will not be notified. Submit any prompt to trigger the inbox check
# hook, which will re-inject the Monitor-arm instructions.
set -uo pipefail

readonly STALENESS_SEC=60   # Must match monitor-check.sh — Monitor loops every 5s

INPUT="$(cat 2>/dev/null || echo '{}')"
SID="$(printf '%s' "${INPUT}" | jq -r '.session_id // empty' 2>/dev/null || echo '')"
MARKER="${HOME}/.claude/handoff/.sessions/${SID}.name"
HEARTBEAT="${HOME}/.claude/handoff/.sessions/${SID}.monitor.alive"

[[ -z "${SID}" || ! -f "${MARKER}" ]] && exit 0

NAME="$(cat "${MARKER}" 2>/dev/null)"
[[ -z "${NAME}" ]] && exit 0

# Heartbeat freshness — same logic as monitor-check.sh.
alive=0
if [[ -f "${HEARTBEAT}" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        mtime="$(stat -f %m "${HEARTBEAT}" 2>/dev/null || echo 0)"
    else
        mtime="$(stat -c %Y "${HEARTBEAT}" 2>/dev/null || echo 0)"
    fi
    now="$(date +%s)"
    [[ $((now - mtime)) -le ${STALENESS_SEC} ]] && alive=1
fi

if [[ ${alive} -eq 1 ]]; then
    printf '[handoff: %s]' "${NAME}"
else
    printf '[handoff: %s ⚠ no monitor]' "${NAME}"
fi
