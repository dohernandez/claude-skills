#!/usr/bin/env bash
# ============================================================================
# HANDOFF SEND — canonical protocol entry point
# ============================================================================
# Wraps the entire send operation in one script so:
#   - Agents don't hand-craft raw `cat >>` / `echo >>` bash (which improvises
#     and trips the permission matcher with compound chains)
#   - The recipient is validated against the live registry before any write
#   - The sender is auto-derived from this process's PPID
#   - The message gets a consistent envelope: header + body + signature
#   - One bash statement, one allow-listed script path, zero prompts
#
# Usage:
#   send.sh <recipient> "single-line message"
#   send.sh <recipient> <<'EOF'
#   multi-line message
#   body content
#   EOF
#   echo "body" | send.sh <recipient>
#
# Exit codes:
#   0 — message appended to recipient's inbox
#   1 — usage error
#   2 — recipient not found in live registry
#   3 — inbox write failed
# ============================================================================

set -euo pipefail

readonly REGISTRY_DIR="${HOME}/.claude/handoff"
readonly REGISTRY="${REGISTRY_DIR}/.registry"

if [[ $# -lt 1 ]]; then
    cat >&2 <<USAGE
usage:
  send.sh <recipient> "single-line message"
  send.sh <recipient> <<EOF             # multi-line via stdin heredoc
  multi-line body
  EOF
  echo "body" | send.sh <recipient>

List live recipients with /handoff list.
USAGE
    exit 1
fi

RECIPIENT="$1"; shift

# Validate recipient is currently registered. Tolerates legacy 5-col and
# current 7-col registry rows.
FOUND="$(awk -F'|' -v r="$RECIPIENT" '$1==r {print "yes"; exit}' "$REGISTRY" 2>/dev/null || true)"
if [[ "$FOUND" != "yes" ]]; then
    echo "ERROR: recipient '${RECIPIENT}' not found in live registry" >&2
    echo "" >&2
    echo "Live sessions:" >&2
    awk -F'|' '{print "  " $1}' "$REGISTRY" 2>/dev/null >&2
    exit 2
fi

# Derive sender by walking up the parent process chain until we hit a PID
# that's registered. send.sh's immediate parent is the bash shell that Claude
# Code spawned to run the tool; claude itself is one or more levels above
# that. Pid is $5 in 7-col rows, $3 in 5-col legacy rows.
SENDER=""
pid=$$
for _ in 1 2 3 4 5; do
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    [[ -z "$pid" || "$pid" == "0" || "$pid" == "1" ]] && break
    SENDER="$(awk -F'|' -v p="$pid" '($5==p || $3==p) {print $1; exit}' "$REGISTRY" 2>/dev/null || true)"
    [[ -n "$SENDER" ]] && break
done
[[ -z "$SENDER" ]] && SENDER="unknown"

# Collect body: positional args (joined by space) or stdin.
if [[ $# -gt 0 ]]; then
    BODY="$*"
else
    BODY="$(cat)"
fi

ISO_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
INBOX="${REGISTRY_DIR}/${RECIPIENT}.signal"

# Build envelope in one printf, write in one >> redirection. Atomic for
# messages under PIPE_BUF (~4KB on macOS); larger messages may interleave
# with concurrent senders but are never lost.
if ! {
    printf '\n[from %s — %s]\n\n%s\n\n— %s\n' "$SENDER" "$ISO_DATE" "$BODY" "$SENDER"
} >> "$INBOX" 2>/dev/null; then
    echo "ERROR: failed to write to ${INBOX}" >&2
    exit 3
fi

BYTES_QUEUED="$(wc -c < "$INBOX" 2>/dev/null | tr -d ' ' || echo '?')"
echo "sent: ${SENDER} -> ${RECIPIENT} (${BYTES_QUEUED} bytes queued in inbox)"
