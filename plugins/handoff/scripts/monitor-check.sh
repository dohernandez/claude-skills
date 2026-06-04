#!/usr/bin/env bash
# ============================================================================
# HANDOFF MONITOR-CHECK
# ============================================================================
# UserPromptSubmit hook. Runs on every user prompt and verifies that the
# session's inbox Monitor is alive by inspecting a heartbeat file the Monitor
# touches each loop iteration.
#
# If the heartbeat is missing or stale (older than the staleness threshold),
# emit an additionalContext reminder telling the agent to (re-)arm a Monitor
# with the canonical command. This keeps the reminder firing on each prompt
# until the agent actually invokes Monitor(...) — fixing the failure mode
# where turn 1 has unrelated user work and the SessionStart instruction gets
# missed.
#
# Stdin: UserPromptSubmit hook input (JSON with session_id, prompt, ...).
# Stdout: Either empty (Monitor alive, no nag) OR a JSON hookSpecificOutput
#         injecting additionalContext.
# Exit:   0 — never block prompt submission; the reminder is advisory.
# ============================================================================
set -euo pipefail

readonly REGISTRY_DIR="${HOME}/.claude/handoff"
readonly SESSIONS_DIR="${REGISTRY_DIR}/.sessions"
readonly STALENESS_SEC=60   # Monitor loops every 5s; 60s = 12 missed beats

HOOK_INPUT="$(cat 2>/dev/null || echo '{}')"
SESSION_ID="$(printf '%s' "${HOOK_INPUT}" | jq -r '.session_id // empty' 2>/dev/null || echo '')"

# No session_id → nothing to check (running outside hook context).
[[ -z "${SESSION_ID}" ]] && exit 0

NAME_FILE="${SESSIONS_DIR}/${SESSION_ID}.name"
[[ ! -f "${NAME_FILE}" ]] && exit 0   # session never registered; skip

NAME="$(cat "${NAME_FILE}" 2>/dev/null || echo '')"
[[ -z "${NAME}" ]] && exit 0

HEARTBEAT="${SESSIONS_DIR}/${SESSION_ID}.monitor.alive"
INBOX="${REGISTRY_DIR}/${NAME}.signal"

# Is the heartbeat fresh? Treat missing OR stale as "Monitor is dead".
alive=0
if [[ -f "${HEARTBEAT}" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        mtime="$(stat -f %m "${HEARTBEAT}" 2>/dev/null || echo 0)"
    else
        mtime="$(stat -c %Y "${HEARTBEAT}" 2>/dev/null || echo 0)"
    fi
    now="$(date +%s)"
    age=$((now - mtime))
    [[ ${age} -le ${STALENESS_SEC} ]] && alive=1
fi

[[ ${alive} -eq 1 ]] && exit 0   # all good — stay quiet

# Heartbeat missing/stale. Inject a reminder so the agent arms the Monitor
# BEFORE handling the user's prompt. Same command shape as register.sh emits
# at SessionStart, plus the heartbeat touch.
CONTEXT="[handoff] Your inbox Monitor for session \`${NAME}\` is NOT running (no fresh heartbeat). BEFORE responding to the user's prompt, arm a persistent Monitor on the inbox so other Claude Code sessions can signal you:

  Monitor(
    description: \"handoff inbox (${NAME})\",
    persistent: true,
    timeout_ms: 3600000,
    command: |
      INBOX=\"${INBOX}\"
      PROCESSING=\"\${INBOX}.processing\"
      HEARTBEAT=\"${HEARTBEAT}\"
      touch \"\$HEARTBEAT\"
      while true; do
        touch \"\$HEARTBEAT\"
        if [ -f \"\$INBOX\" ] && mv \"\$INBOX\" \"\$PROCESSING\" 2>/dev/null; then
          payload=\$(cat \"\$PROCESSING\" 2>/dev/null)
          rm -f \"\$PROCESSING\" 2>/dev/null
          if [ -n \"\$payload\" ]; then
            echo \"handoff: \$payload\"
          fi
        fi
        sleep 5
      done
  )

Without this, you cannot receive handoff signals from other Claude sessions. This reminder fires on every user prompt until the Monitor's heartbeat (${HEARTBEAT}) is fresh."

jq -nc --arg c "${CONTEXT}" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $c
    }
}'

exit 0
