#!/usr/bin/env bash
# Use env so we pick up the homebrew bash (5.x) on macOS rather than the
# ancient /bin/bash 3.2 which has parser bugs with $(cat <<EOF ... EOF)
# patterns inside heredocs (the SessionStart context emission below).
set -euo pipefail

# ============================================================================
# HANDOFF REGISTER
# ============================================================================
# Runs at every Claude Code SessionStart. Three jobs:
#
#   1. Garbage-collect dead entries from ~/.claude/handoff/.registry —
#      a session ends when its `claude` process dies; we detect that
#      via `kill -0 <pid>` and prune the row.
#
#   2. Pick a name for this session:
#        - $HANDOFF_NAME if explicitly set
#        - else basename of $CLAUDE_PROJECT_DIR (the cwd Claude started in)
#      and auto-suffix with -2/-3/... if a LIVE session already owns the
#      default. Result is written to the per-session marker so statusLine
#      and /handoff whoami can read it.
#
#   3. Capture canonical repo identity + branch so /handoff list can show
#      WHO controls WHAT regardless of cwd (worktrees → same repo identity).
#        - $HANDOFF_REPO overrides the auto-detected repo
#        - $HANDOFF_ROLE overrides the auto-detected branch
#
#   4. Emit a SessionStart hook JSON response telling the agent to arm
#      a Monitor on its inbox file. Only the agent can call the Monitor
#      tool; the hook plants the instruction.
#
# Registry schema (7 columns, |-separated):
#   name|repo|branch|cwd|pid|started_at|session_id
#
# Legacy 5-column rows (name|cwd|pid|started_at|session_id) are tolerated
# during GC; they get repo="-" and branch="-" until the owning session
# restarts and re-registers under the new schema.
#
# Stdin: SessionStart hook input (JSON with session_id, cwd, source, ...).
# Stdout: SessionStart hook output (JSON with hookSpecificOutput).
# Stderr: diagnostics (logged by Claude Code; not seen by the agent).
# Exit:   0 = continue session. Non-zero blocks startup — don't.
# ============================================================================

readonly REGISTRY_DIR="${HOME}/.claude/handoff"
readonly REGISTRY="${REGISTRY_DIR}/.registry"
readonly SESSIONS_DIR="${REGISTRY_DIR}/.sessions"
readonly LOCKDIR="${REGISTRY_DIR}/.lock.d"
# Scripts live in <plugin>/scripts; plugin assets (roles/, specialist-prompt.md,
# roles.yaml.example) live one level up. ${CLAUDE_PLUGIN_ROOT} is exported to
# hook processes by Claude Code; fall back to a BASH_SOURCE-derived path when
# the script is run directly.
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/roles-lib.sh"

mkdir -p "${REGISTRY_DIR}" "${SESSIONS_DIR}"
touch "${REGISTRY}"

# Seed the GLOBAL roles.yaml from the shipped template on first run so users
# have a documented file ready to edit (and /handoff role set has a target).
# Never overwrites an existing map.
if [[ ! -f "${REGISTRY_DIR}/roles.yaml" && -r "${PLUGIN_ROOT}/roles.yaml.example" ]]; then
    cp "${PLUGIN_ROOT}/roles.yaml.example" "${REGISTRY_DIR}/roles.yaml" 2>/dev/null || true
fi

# Portable mutex (macOS ships without flock). `mkdir` is atomic on POSIX
# filesystems — if two processes race, exactly one succeeds.
acquire_lock() {
    local tries=0
    while ! mkdir "${LOCKDIR}" 2>/dev/null; do
        # Stale lock detection: if the holding PID is dead, steal it.
        if [[ -f "${LOCKDIR}/pid" ]]; then
            local holder; holder="$(cat "${LOCKDIR}/pid" 2>/dev/null || echo '')"
            if [[ -n "${holder}" ]] && ! kill -0 "${holder}" 2>/dev/null; then
                rm -rf "${LOCKDIR}"
                continue
            fi
        fi
        tries=$((tries + 1))
        [[ ${tries} -gt 50 ]] && return 1  # 50 × 0.1s = 5s ceiling
        sleep 0.1
    done
    echo "${PPID}" > "${LOCKDIR}/pid"
}
release_lock() {
    rm -rf "${LOCKDIR}" 2>/dev/null || true
}
trap release_lock EXIT

# ============================================================================
# Repo / branch detection — stable across worktrees.
#   - $HANDOFF_REPO / $HANDOFF_ROLE always win.
#   - Repo: parse remote.origin.url → "org/repo". Falls back to the basename
#     of the parent of git-common-dir (which is the main repo path even from
#     inside a worktree). Falls back to "-" for non-git directories.
#   - Branch: git rev-parse --abbrev-ref HEAD, or "-" for non-git.
# ============================================================================
detect_repo() {
    handoff_detect_repo "$1"
}

detect_branch() {
    local cwd="$1"
    if [[ -n "${HANDOFF_ROLE:-}" ]]; then
        printf '%s' "${HANDOFF_ROLE}"
        return
    fi
    git -C "${cwd}" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '%s' "-"
}

# ============================================================================
# Read hook input — bail out gracefully if not running under a hook.
# ============================================================================
HOOK_INPUT="$(cat 2>/dev/null || echo '{}')"
SESSION_ID="$(printf '%s' "${HOOK_INPUT}" | jq -r '.session_id // empty' 2>/dev/null || echo '')"
CWD="$(printf '%s' "${HOOK_INPUT}" | jq -r '.cwd // empty' 2>/dev/null || echo "${PWD}")"
SOURCE="$(printf '%s' "${HOOK_INPUT}" | jq -r '.source // "startup"' 2>/dev/null || echo 'startup')"

# Fallbacks if hook stdin was empty (e.g. running register.sh by hand).
SESSION_ID="${SESSION_ID:-manual-$$}"
CWD="${CWD:-${PWD}}"

REPO="$(detect_repo "${CWD}")"
BRANCH="$(detect_branch "${CWD}")"

# ============================================================================
# Speculative marker write — make the statusLine indicator visible ASAP.
# Claude Code's statusline.sh runs early in session boot (often in parallel
# with SessionStart hooks). If we wait until after lock+GC+migration to write
# the marker, the first statusLine render sees nothing and the user has no
# `[handoff: <name>]` indicator until they type something to trigger a re-
# render. Write the speculative name first so statusline.sh can pick it up
# immediately; pick_name() below may override with a -N suffix on collision,
# and we'll overwrite the marker with the final name then.
# ============================================================================
SPECULATIVE_NAME="${HANDOFF_NAME:-$(basename "${CWD}")}"
echo "${SPECULATIVE_NAME}" > "${SESSIONS_DIR}/${SESSION_ID}.name"

# ============================================================================
# GC: remove rows whose PID is dead. Tolerates 5-col legacy and 7-col rows.
# Rewrites everything in the new 7-col schema; legacy rows get repo/branch
# defaulted to "-" until the owning session restarts.
# ============================================================================
gc_registry() {
    local tmp; tmp=$(mktemp)
    if [[ -s "${REGISTRY}" ]]; then
        local line nfields name repo branch cwd pid started_at sid
        while IFS= read -r line || [[ -n "${line:-}" ]]; do
            [[ -z "${line}" ]] && continue
            nfields=$(printf '%s' "${line}" | awk -F'|' '{print NF}')
            if [[ "${nfields}" -eq 5 ]]; then
                # Legacy: name|cwd|pid|started_at|sid
                IFS='|' read -r name cwd pid started_at sid <<< "${line}"
                repo="-"; branch="-"
            elif [[ "${nfields}" -ge 7 ]]; then
                # Current: name|repo|branch|cwd|pid|started_at|sid
                IFS='|' read -r name repo branch cwd pid started_at sid <<< "${line}"
            else
                continue
            fi
            [[ -z "${name:-}" ]] && continue
            [[ -z "${repo:-}" ]] && repo="-"
            [[ -z "${branch:-}" ]] && branch="-"
            if kill -0 "${pid}" 2>/dev/null; then
                printf '%s|%s|%s|%s|%s|%s|%s\n' \
                    "${name}" "${repo}" "${branch}" "${cwd}" "${pid}" "${started_at}" "${sid}" >> "${tmp}"
            fi
        done < "${REGISTRY}"
    fi
    mv "${tmp}" "${REGISTRY}"
}

# ============================================================================
# Name resolution with collision-aware auto-suffix.
# Caller must hold the lock — this function reads the registry.
# After GC, all rows are 7-col so pid is $5. We still tolerate 5-col rows
# (in case GC was skipped) by falling back to $3.
# ============================================================================
pick_name() {
    local default_name chosen_name candidate n suffix existing_pid
    default_name="$(basename "${CWD}")"
    chosen_name="${HANDOFF_NAME:-${default_name}}"

    n=1; suffix=""
    while :; do
        candidate="${chosen_name}${suffix}"
        existing_pid="$(awk -F'|' -v c="${candidate}" '$1==c {if(NF>=7) print $5; else print $3; exit}' "${REGISTRY}" 2>/dev/null || true)"
        if [[ -z "${existing_pid}" ]] || ! kill -0 "${existing_pid}" 2>/dev/null; then
            # Slot is free, or stale (GC already pruned it above).
            break
        fi
        n=$((n + 1))
        suffix="-${n}"
    done
    printf '%s' "${candidate}"
}

# ============================================================================
# Register this session — atomic via flock so concurrent starts don't race.
# ============================================================================
acquire_lock || { echo "[handoff] could not acquire lock — skipping registration" >&2; exit 0; }

gc_registry
FINAL_NAME="$(pick_name)"

# If we're resuming and a row for our SESSION_ID already exists, drop it
# first so re-registration doesn't accumulate duplicates. session_id is the
# last field in both 5-col and 7-col schemas, so end-anchored grep works.
if [[ -n "${SESSION_ID}" ]] && grep -q "|${SESSION_ID}\$" "${REGISTRY}" 2>/dev/null; then
    grep -v "|${SESSION_ID}\$" "${REGISTRY}" > "${REGISTRY}.tmp" || true
    mv "${REGISTRY}.tmp" "${REGISTRY}"
fi

# ============================================================================
# Orphan inbox migration.
# If this session previously registered under a different name (because
# pick_name shifted us to a new suffix — e.g. e2e-2 → e2e-3 since another
# session claimed e2e-2 while we were offline), pre-existing messages in
# the OLD inbox file would never be drained. Move them to the NEW inbox so
# the agent's Monitor delivers them on its next poll.
#
# Safety: only migrate if the OLD name has no live owner. Otherwise we'd
# steal messages from another session that legitimately holds that slot.
# ============================================================================
MIGRATED_FROM=""
if [[ -f "${SESSIONS_DIR}/${SESSION_ID}.name" ]]; then
    PREV_NAME="$(cat "${SESSIONS_DIR}/${SESSION_ID}.name" 2>/dev/null || echo '')"
    if [[ -n "${PREV_NAME}" && "${PREV_NAME}" != "${FINAL_NAME}" ]]; then
        OLD_INBOX="${REGISTRY_DIR}/${PREV_NAME}.signal"
        NEW_INBOX="${REGISTRY_DIR}/${FINAL_NAME}.signal"
        if [[ -f "${OLD_INBOX}" ]]; then
            # Is the OLD name currently owned by another live session?
            OWNER_PID="$(awk -F'|' -v n="${PREV_NAME}" '$1==n {if(NF>=7) print $5; else print $3; exit}' "${REGISTRY}" 2>/dev/null || true)"
            if [[ -z "${OWNER_PID}" ]] || ! kill -0 "${OWNER_PID}" 2>/dev/null; then
                # Safe: no live owner. Prepend OLD to NEW (chronological order:
                # OLD messages are older).
                if [[ -f "${NEW_INBOX}" ]]; then
                    tmp_inbox="$(mktemp)"
                    cat "${OLD_INBOX}" "${NEW_INBOX}" > "${tmp_inbox}" 2>/dev/null && mv "${tmp_inbox}" "${NEW_INBOX}"
                else
                    cp "${OLD_INBOX}" "${NEW_INBOX}"
                fi
                rm -f "${OLD_INBOX}"
                MIGRATED_FROM="${PREV_NAME}"
                echo "[handoff] migrated orphan inbox: ${PREV_NAME}.signal -> ${FINAL_NAME}.signal" >&2
            else
                echo "[handoff] skipping migration: ${PREV_NAME} now owned by live PID ${OWNER_PID}" >&2
            fi
        fi
    fi
fi

printf '%s|%s|%s|%s|%s|%s|%s\n' \
    "${FINAL_NAME}" "${REPO}" "${BRANCH}" "${CWD}" "${PPID}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${SESSION_ID}" \
    >> "${REGISTRY}"

release_lock

# ============================================================================
# Reap orphan Monitors for this inbox name from prior session_ids (typical
# cause: /clear or /compact changes session_id but leaves the old Monitor
# child alive, racing the new one on the inbox file). gc.sh spares any
# Monitor whose heartbeat path matches the CURRENT session_id.
# ============================================================================
"${SCRIPT_DIR}/gc.sh" "${FINAL_NAME}" "${SESSION_ID}" || true

# Update per-session marker if pick_name shifted the suffix from the
# speculative write at the top of the script. Read by statusline.sh and
# /handoff whoami. Overwrites PREV_NAME so the next register cycle migrates
# from FINAL_NAME.
if [[ "${FINAL_NAME}" != "${SPECULATIVE_NAME}" ]]; then
    echo "${FINAL_NAME}" > "${SESSIONS_DIR}/${SESSION_ID}.name"
fi

# ============================================================================
# Auto-specialist resolution.
#
# Look up this session's repo across the role tiers (project > global) to pick
# a role overlay + secondary mentions + cache path. The resulting block is
# appended to the SessionStart additionalContext so the agent gets its
# specialist lens on turn 1 without needing a separate /handoff arm call.
#
# Skipped if HANDOFF_NO_AUTO_SPECIALIST=1 (escape hatch for ops sessions).
# Cache: lookup by repo+branch slug, same as arm.sh.
# Discovery: the receiver is told to LOAD the prompts but DEFER full Step 1-5
# discovery until the user asks something repo-related — turn 1 must not be
# blocked on cold-start scanning.
# ============================================================================
AUTO_SPECIALIST_BLOCK=""
if [[ "${HANDOFF_NO_AUTO_SPECIALIST:-0}" != "1" ]]; then
    DEFAULT_PROMPT="${PLUGIN_ROOT}/specialist-prompt.md"
    CACHE_DIR="${REGISTRY_DIR}/specialist-cache"

    ROLE_OVERLAY_PATH=""
    SECONDARY_MENTIONS=""
    ROLE_MATCH="$(handoff_lookup_role "${CWD}" "${REPO}")"
    if [[ -n "${ROLE_MATCH}" ]]; then
        ROLE_SPEC="${ROLE_MATCH%%$'\t'*}"
        IFS='+' read -ra ROLE_PARTS <<< "${ROLE_SPEC}"
        PRIMARY="${ROLE_PARTS[0]}"
        ROLE_OVERLAY_PATH="$(handoff_resolve_lens "${CWD}" "${PRIMARY}")"
        for (( i=1; i<${#ROLE_PARTS[@]}; i++ )); do
            sec="${ROLE_PARTS[i]}"
            [[ -z "${sec}" ]] && continue
            sec_lens="$(handoff_resolve_lens "${CWD}" "${sec}")"
            if [[ -n "${sec_lens}" ]]; then
                entry="${sec} (see ${sec_lens})"
            else
                entry="${sec}"
            fi
            if [[ -z "${SECONDARY_MENTIONS}" ]]; then
                SECONDARY_MENTIONS="${entry}"
            else
                SECONDARY_MENTIONS="${SECONDARY_MENTIONS}, ${entry}"
            fi
        done
    fi

    # Resolve the anchor branch for cache routing — usually a base branch
    # (main, v0.5, etc.) so feature branches share the base's cache.
    ANCHOR_BRANCH=""
    if [[ -n "${CWD}" && -n "${BRANCH}" && "${BRANCH}" != "-" ]]; then
        ANCHOR_BRANCH="$("${SCRIPT_DIR}/resolve-base.sh" "${CWD}" "${BRANCH}" 2>/dev/null || true)"
    fi
    [[ -z "${ANCHOR_BRANCH}" ]] && ANCHOR_BRANCH="${BRANCH}"

    AUTO_CACHE_PATH=""
    if [[ "${REPO}" != "-" && "${ANCHOR_BRANCH}" != "-" ]]; then
        repo_slug="${REPO//\//--}"
        branch_slug="${ANCHOR_BRANCH//\//--}"
        AUTO_CACHE_PATH="${CACHE_DIR}/${repo_slug}@${branch_slug}.md"
        mkdir -p "${CACHE_DIR}" 2>/dev/null || true
    fi

    if [[ -n "${ROLE_OVERLAY_PATH}" ]]; then
        AUTO_SPECIALIST_BLOCK="

[handoff/specialist] You are also being auto-armed as the domain specialist for this repository on session start (in addition to the Monitor arming above).

Read these two prompt files for your specialist lens:
1. Base specialist contract (principles, discovery sequence, answer format, NOT-to-do, cache contract):
   ${DEFAULT_PROMPT}
2. Role overlay (apply the base through this lens — identity, role-specific domain focus, role-specific don'ts):
   ${ROLE_OVERLAY_PATH}"

        if [[ -n "${SECONDARY_MENTIONS}" ]]; then
            AUTO_SPECIALIST_BLOCK="${AUTO_SPECIALIST_BLOCK}

This repo also makes use of: ${SECONDARY_MENTIONS}. Familiarize yourself with these during any repo-related work. For items with a (see <file>) reference, load that role's prompt only if a question pushes you into that area."
        fi
    elif [[ "${REPO}" != "-" ]]; then
        AUTO_SPECIALIST_BLOCK="

[handoff/specialist] You are also being auto-armed as the domain specialist for this repository on session start.

Read this prompt file for your specialist lens:
   ${DEFAULT_PROMPT}

(No role mapping for ${REPO} yet — using the generic senior-engineer prompt. To add a role: run \`/handoff role set <role>\` in this repo, or edit ${REGISTRY_DIR}/roles.yaml.)"
    fi

    if [[ -n "${AUTO_SPECIALIST_BLOCK}" && -n "${AUTO_CACHE_PATH}" ]]; then
        AUTO_SPECIALIST_BLOCK="${AUTO_SPECIALIST_BLOCK}

Repository context cache: ${AUTO_CACHE_PATH}
Anchored to base branch: ${ANCHOR_BRANCH} (your current branch is ${BRANCH}; the cache is shared across feature branches off this base)
If this file exists, treat it as a prior agent's mental model of this repo. Apply the Cache contract (§6 of the base prompt; schema 4). When current != anchor, the \"use as foundation\" decision requires BOTH \`<cache.git_rev>..${ANCHOR_BRANCH}\` (anchor-advance: PRs merged into the base since the cache was last written) AND \`${ANCHOR_BRANCH}..HEAD\` (your feature delta) to be hot-file-clean. Write your synthesis back at the end of any discovery you perform, preserving \`anchor_branch: ${ANCHOR_BRANCH}\` and setting \`git_rev\` to the anchor tip (\`git rev-parse origin/${ANCHOR_BRANCH}\` or local \`${ANCHOR_BRANCH}\`), NOT your own HEAD.

DEFER FULL DISCOVERY: do NOT proactively run Step 1-5 discovery on turn 1. Load the prompts and the cache (if present) as context, then handle the user's prompt. Run discovery only when the user asks a repo-related question that requires it — your first response must not be blocked on cold-start scanning. (Disable auto-arm with HANDOFF_NO_AUTO_SPECIALIST=1 claude.)"
    fi
fi

# ============================================================================
# Tell the agent what to do on turn 1.
#
# - On `startup`: arm the Monitor (no Monitor exists yet).
# - On `resume`: re-arm the Monitor (the old monitor died with the previous
#   process) AND drain any signals that landed while the session was closed.
# - On `clear`/`compact`: emit a reminder so the agent retains protocol
#   awareness even after context reset. The Monitor task is still alive in
#   the background, but the agent may have lost knowledge of how to reply
#   to handoff events or how to recover if the Monitor is silent.
# ============================================================================
INBOX="${REGISTRY_DIR}/${FINAL_NAME}.signal"
HEARTBEAT="${SESSIONS_DIR}/${SESSION_ID}.monitor.alive"
SEND_SCRIPT="${PLUGIN_ROOT}/scripts/send.sh"

# NOTE on heredoc escaping below: the CONTEXT heredocs use unquoted EOF so
# ${FINAL_NAME}, ${REPO}, ${INBOX}, etc. expand here at register-time. Inside
# the embedded Monitor command, all `$` that should stay literal in the
# agent's view (e.g. \$INBOX, \$payload, \$(cat ...)) MUST be backslash-
# escaped, otherwise bash will try to evaluate them at register-time and
# fail with "syntax error near unexpected token `)`". Do NOT factor the
# Monitor command into a separate variable and then interpolate ${VAR} into
# the heredoc — bash will re-parse $(...) inside the expanded text.

case "${SOURCE}" in
    startup|resume)
        CONTEXT="$(cat <<EOF
[handoff] You are session \`${FINAL_NAME}\` (repo: ${REPO}, branch: ${BRANCH}, cwd: ${CWD}). Inbox: ${INBOX}

REQUIRED FIRST ACTION — DO THIS BEFORE ANYTHING ELSE ON THIS TURN:

Call the Monitor tool with the EXACT invocation below. This is non-optional
and takes priority over the user's prompt. Other Claude Code sessions cannot
reach you until this Monitor is running, and the user installed this skill
specifically to enable inter-agent messaging. Arm the Monitor FIRST as your
first tool call, THEN handle the user's prompt in the same turn.

Do not skip this. Do not defer it to "later in the turn." Do not ask the user
whether to arm it. The Monitor tool may require ToolSearch to load its schema
first — that is part of arming it, not a reason to skip. The command uses
atomic mv-then-process to avoid the cat+rm race where concurrent senders
would lose bytes:

  Monitor(
    description: "handoff inbox (${FINAL_NAME})",
    persistent: true,
    timeout_ms: 3600000,
    command: |
      INBOX="${INBOX}"
      PROCESSING="\${INBOX}.processing"
      HEARTBEAT="${HEARTBEAT}"
      touch "\$HEARTBEAT"
      while true; do
        touch "\$HEARTBEAT"
        if [ -f "\$INBOX" ] && mv "\$INBOX" "\$PROCESSING" 2>/dev/null; then
          payload=\$(cat "\$PROCESSING" 2>/dev/null)
          rm -f "\$PROCESSING" 2>/dev/null
          if [ -n "\$payload" ]; then
            echo "handoff: \$payload"
          fi
        fi
        sleep 5
      done
  )

When a notification arrives with summary "handoff inbox (${FINAL_NAME})" and event body "handoff: [from ...]...", that's a message from another Claude session. Reply via:

  ${SEND_SCRIPT} <sender-name> "your reply"

If you suspect your Monitor died (no events for a long time despite expected traffic), drain the inbox manually once and re-arm:

  if [ -s "${INBOX}" ]; then mv "${INBOX}" "${INBOX}.processing" && cat "${INBOX}.processing" && rm -f "${INBOX}.processing"; fi

Source: ${SOURCE}. ${SOURCE_HINT:-}
EOF
)"
        if [[ "${SOURCE}" == "resume" ]]; then
            CONTEXT="${CONTEXT//SOURCE_HINT/On resume the previous Monitor died with the old process — re-arm. Any signals sent while the session was closed will be in the inbox; the new Monitor will drain them on the first poll.}"
        fi
        if [[ -n "${MIGRATED_FROM}" ]]; then
            CONTEXT="${CONTEXT}

[handoff] NOTE: Your previous inbox name was \`${MIGRATED_FROM}\`. Pending messages there have been migrated to your current inbox (\`${FINAL_NAME}.signal\`). Your Monitor will see them on its first poll. Other agents that try to reach you at \`${MIGRATED_FROM}\` will not be heard — if you sent any handoffs identifying yourself as ${MIGRATED_FROM}, consider sending a follow-up under your new name."
        fi
        if [[ -n "${AUTO_SPECIALIST_BLOCK}" ]]; then
            CONTEXT="${CONTEXT}${AUTO_SPECIALIST_BLOCK}"
        fi
        ;;
    clear|compact)
        # Context was just reset (memory wiped). The Monitor task is still
        # running in the background — but the agent may have lost awareness
        # of the protocol. Re-seed minimal context so handoff events that
        # arrive after compaction still get a sensible reply.
        CONTEXT="$(cat <<EOF
[handoff] Session \`${FINAL_NAME}\` (repo: ${REPO}, branch: ${BRANCH}). Inbox: ${INBOX}

Your inbox Monitor was armed earlier in this session and continues to run in the background. When a notification arrives with summary "handoff inbox (${FINAL_NAME})" and event body starting "handoff: [from ...]...", that's a message from another Claude session. Reply via:

  ${SEND_SCRIPT} <sender-name> "your reply"

If you suspect your Monitor died (silent for a long time despite expected traffic), drain the inbox manually once and re-arm a fresh Monitor (same command as on session start):

  if [ -s "${INBOX}" ]; then mv "${INBOX}" "${INBOX}.processing" && cat "${INBOX}.processing" && rm -f "${INBOX}.processing"; fi

Source: ${SOURCE}.
EOF
)"
        if [[ -n "${AUTO_SPECIALIST_BLOCK}" ]]; then
            CONTEXT="${CONTEXT}${AUTO_SPECIALIST_BLOCK}"
        fi
        ;;
    *)
        CONTEXT=""
        ;;
esac

# Emit the SessionStart response. additionalContext is what the agent sees.
if [[ -n "${CONTEXT}" ]]; then
    jq -nc --arg c "${CONTEXT}" '{
        hookSpecificOutput: {
            hookEventName: "SessionStart",
            additionalContext: $c
        }
    }'
fi

exit 0
