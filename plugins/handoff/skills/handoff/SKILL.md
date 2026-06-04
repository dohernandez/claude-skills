---
name: handoff
description: Send messages between Claude Code sessions on the same machine. Use `list` to see live sessions, `send` to message another, `arm` to set up another session as a domain specialist, `role` to manage per-repo specialist mappings, `whoami` to confirm your own name, `monitor` to force-arm the inbox listener. Inbox monitoring AND specialist auto-arming both fire at session start via the SessionStart hook (opt out with `HANDOFF_NO_AUTO_SPECIALIST=1`).
user-invocable: true
---

# Handoff

Filesystem-based agent-to-agent mailbox for Claude Code sessions on the same machine. Bidirectional, ad-hoc, no daemon. Each session registers a name at start, watches its own inbox (`~/.claude/handoff/<name>.signal`), and can write to any other session's inbox.

> **Script paths.** All helper scripts live at `${CLAUDE_PLUGIN_ROOT}/scripts/`. This variable is set for the plugin's hooks and skill invocations. The SessionStart hook also injects the **resolved absolute path** of `send.sh` into your context — prefer that for replies. State (registry, inboxes, caches, role maps) always lives under `~/.claude/handoff/`, independent of where the plugin is installed.

## When to use

- You're working in one session and want another session (in a different repo or worktree) to take an action — e.g. "I just merged the dev-env fix, dispatch the e2e harness".
- You want to keep this session's context free of work that belongs to the other repo.

## State layout

```
~/.claude/handoff/
├── .registry          # name|repo|branch|cwd|pid|started_at|session_id  (one line per live session)
├── .lock.d/           # mkdir-based mutex for atomic registry edits
├── .sessions/
│   ├── <session_id>.name           # per-session name marker; read by statusLine + whoami
│   └── <session_id>.monitor.alive  # Monitor heartbeat
├── roles.yaml         # GLOBAL role map (seeded from the shipped template on first run)
├── specialist-cache/  # per-repo+branch context caches
└── <name>.signal      # inbox file; written by send, drained by the recipient's Monitor
```

Registry columns:

- **name** — `${HANDOFF_NAME:-$(basename $CWD)}`, auto-suffixed `-2`/`-3`/... if a live session already owns the default
- **repo** — canonical repo identity (e.g. `acme/widget`), derived from `git remote get-url origin`. Stable across worktrees. Override with `HANDOFF_REPO=...`. Falls back to `-` for non-git directories.
- **branch** — `git rev-parse --abbrev-ref HEAD` at register time. Captured once. Override with `HANDOFF_ROLE=...` when branch isn't the right label.
- **cwd** — the actual working directory (which is what a worktree path looks like)
- **pid**, **started_at**, **session_id** — internal bookkeeping

Override at session start:

```bash
HANDOFF_NAME=e2e-debug claude            # custom inbox name
HANDOFF_REPO=acme/widget claude          # custom repo label (rare)
HANDOFF_ROLE=v0.6-spike claude           # custom role replacing the branch column
```

## Subcommands

### `/handoff list`

Show all live sessions with their repo + branch so you can route correctly:

```
NAME              REPO                BRANCH                      CWD                                            PID    STARTED              SESSION_ID
widget            acme/widget         main                        /Users/me/code/widget                          95707  2026-05-18T08:58:23Z  52b1d2c7-...
widget-2          acme/widget         perf/precompile             /Users/me/code/widget                          54783  2026-05-17T22:33:29Z  8ffe0c73-...
fix-123           acme/widget         fix/123                     /Users/me/worktree/widget/fix-123              12345  2026-05-18T09:00:00Z  abcdef01-...
api-2             acme/payments-api   e2e-debug                   /Users/me/code/payments-api                    9570   2026-05-17T14:30:54Z  8e91df17-...
```

Implementation:

```bash
column -t -s '|' ~/.claude/handoff/.registry
```

Routing decision: pick by **repo + branch** rather than name alone, so worktrees are first-class.

### `/handoff send <name> <message>`

Use the canonical `send.sh` wrapper. It validates the recipient against the live registry, auto-derives the sender from this process's PPID, wraps the body in a `[from <sender> — <iso>]` envelope, and writes in one allow-listed bash statement (zero permission prompts).

**Short / single-line message:**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/send.sh <recipient> "your message here"
```

**Multi-line message (heredoc piped to script's stdin):**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/send.sh <recipient> <<'EOF'
Multi-line body content.

Can span many lines, include code blocks, lists, anything.
EOF
```

**Piped stdin (e.g., from a file):**
```bash
cat my-message.txt | ${CLAUDE_PLUGIN_ROOT}/scripts/send.sh <recipient>
```

The script handles:
- Recipient validation against `.registry` — fails fast with a "Live sessions:" listing if the name isn't registered
- Sender derivation by matching PPID against `.registry`
- Envelope wrapping (`[from X — iso]` header + body + `— X` footer)
- Atomic append (single `>>` redirection)

Exit codes: `0` sent, `1` usage error, `2` recipient unknown, `3` write failed.

### Why a wrapper instead of raw `cat >>` or `echo >>`?

Hand-crafted bash improvises and trips the permission matcher in ways the agent can't always predict:
- **Tilde paths** (`~/.claude/handoff/...`) don't match permission rules using `/Users/<user>/...` because the matcher reads the literal command string before shell expansion.
- **Compound commands** (`cat > /tmp/x && echo preview && cat /tmp/x >> ~/.../signal && echo sent`) are matched as one command-as-a-whole. No single allow rule covers a multi-statement chain, so the user is prompted.
- **Subshells** (`(cat ... ) >> ...`) treat the parens as opaque to the matcher.

`send.sh` is one absolute-path invocation, allow-listed via `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/send.sh:*)`. Heredoc body becomes stdin to the script, not a separate statement, so the matcher only sees the script call. No prompts ever.

**Don't bypass `send.sh`** by writing raw `cat >>` / `echo >>` against the inbox file. You'll lose the envelope formatting, the recipient validation, and the sender derivation.

### `/handoff arm [--to <name> | <name>] [--prompt <path>] [--no-cache | --rebuild-cache]`

Arm a live session as a domain specialist by delivering a role prompt over the handoff channel. Default prompt is the senior-engineer onboarding at `${CLAUDE_PLUGIN_ROOT}/specialist-prompt.md`. Override with `--prompt <path>` to deliver a different role (the path must be readable by the receiving session; absolute paths are safest).

**Recipient resolution (in order):**
1. `--to <name>` flag (explicit)
2. Bare positional `<name>` (also explicit)
3. Neither → **self-arm**: the current session arms itself, with the recipient auto-detected from the caller's PPID chain via the registry

Self-arm is the common case ("prime me as a specialist on the repo I'm in") and requires no arguments. Do not prompt the user with the live-sessions table for bare `/handoff arm` — just invoke `arm.sh` and let it self-resolve. Only show the table if recipient resolution fails.

**Self-arm (most common):**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/arm.sh
```

**Arm another session (explicit flag form):**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/arm.sh --to <recipient>
```

**Arm another session (positional form, also accepted):**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/arm.sh <recipient>
```

**With a custom prompt (caching disabled):**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/arm.sh [--to <recipient>] --prompt /path/to/role.md
```

**Force fresh cache regeneration (default prompt only):**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/arm.sh [--to <recipient>] --rebuild-cache
```

**Default prompt, no cache (debugging / one-off):**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/arm.sh [--to <recipient>] --no-cache
```

`arm.sh` is a composite operation with two halves:

1. **Delivery (handled by the script):** validates the recipient against `.registry`, verifies the prompt file is readable, computes a per-repo+branch cache path from the recipient's registry row, and pipes a structured arming message into `send.sh`. The receiver gets a normal handoff envelope whose body tells them to read the prompt file, apply the Cache contract (§6 of the prompt) to decide whether to use/supplement/regen the cache, verify their own Monitor is alive (running `/handoff monitor` if not), and acknowledge with a cache decision (`used | supplemented | regenerated | none`).
2. **Self-check (handled by you, the caller):** immediately after `arm.sh` exits 0, run the same Monitor self-check as `/handoff monitor` for *this* session. Without it, the receiver's acknowledgment may land in an empty inbox. Both ends need a live Monitor for the dialogue to work.

**Role routing details:**
- When the default prompt is used (no `--prompt` override), `arm.sh` looks up the recipient's `<org>/<repo>` across the role tiers (project > global; see [`/handoff role`](#handoff-role-show--list--set--unset--edit--init)). If matched, the message instructs the receiver to read TWO files in order: (1) the base contract `specialist-prompt.md` and (2) the role overlay lens `roles/<primary>.md`. The overlay sharpens the role identity, discovery hints, and domain focus while reusing the base for the shared contract.
- Mapping format: `<org>/<repo>: <primary>[+<secondary>[+<tertiary>...]]`. Examples:
  - `acme/payments-api: golang+gha`
  - `acme/infra: devops+ansible+terraform+gcp+aws`
- Secondaries are surfaced in the message body as a "this repo also makes use of: X, Y, Z" awareness line. If a `roles/<X>.md` lens exists for a secondary (in any tier), the message appends `(see <file>)`; otherwise it's a name-only mention.
- Unmapped repos fall back to `specialist-prompt.md` alone, with a stderr warning so you can add the mapping with `/handoff role set`.
- For `--prompt` overrides: role lookup is skipped entirely (custom prompt is a bespoke persona).

**Cache routing details:**
- Cache path: `~/.claude/handoff/specialist-cache/<repo-slug>@<anchor-branch-slug>.md` where `/` in `org/repo` and the anchor branch becomes `--`.
- The cache is keyed by **anchor branch** (a base/integration branch like `main`, `v0.5`, `v0.6`), NOT by the recipient's literal current branch. `resolve-base.sh` picks the anchor:
  - If current branch matches the pattern (`main`/`master`/`develop`/`v<n>[.<m>[.<p>]]`) it IS the anchor.
  - Otherwise, the closest-by-commit-distance ancestor matching that pattern (checking both local and `origin/` refs) wins.
  - Override with `HANDOFF_BASE_BRANCH=<name>`.
- **Effect:** all feature branches off the same base SHARE one cache file.
- Cache is included when ALL of these are true: default prompt is used, `--no-cache` is not set, and the recipient's registry row has real `repo` and `branch` values (not `-`). If the base prompt or role overlay file changes, the receiver's `prompt_sha256` / `role_sha256` checks regenerate the cache automatically. Schema bumps (currently `4`) also force regeneration.
- **`git_rev` semantics:** the writer records `git_rev` as the **anchor branch's tip** at write time, not their own HEAD, so `<cache.git_rev>..<anchor_branch>` means "anchor commits since the cache was last written". The feature-branch foundation check requires BOTH the anchor-advance diff AND the feature delta (`<anchor_branch>..HEAD`) to be hot-file-clean.
- **Age cap:** caches older than **30 days** trigger full regen regardless of hot-file diff state.
- For `--prompt` overrides: caching is always disabled.

Exit codes: `0` armed, `1` usage error, `2` recipient unknown, `3` write failed, `4` prompt file not readable.

The same wrapper rationale covers `arm.sh` too — allow-list via `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/arm.sh:*)`.

### `/handoff role` (show | list | set | unset | edit | init)

Manage the per-repo specialist map without hand-editing YAML. Mappings resolve across three tiers, **first match wins**:

1. **Env** — `$HANDOFF_ROLES_YAML` (one file, wholesale; power-user / testing)
2. **Project** — `<repo-root>/.claude/handoff/roles.yaml` (committed to the repo, overrides global, shared with the whole team)
3. **Global** — `~/.claude/handoff/roles.yaml` (your personal default across all repos)

Overlay `.md` lenses layer the same way: `<repo-root>/.claude/handoff/roles/<name>.md` → `~/.claude/handoff/roles/<name>.md` → `${CLAUDE_PLUGIN_ROOT}/roles/<name>.md` (shipped library). Shipped lenses: `golang`, `rust`, `python`, `typescript`, `blockchain-ts`, `devops`, `lua`.

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/role.sh show [<org/repo>]    # resolved role + source tier
${CLAUDE_PLUGIN_ROOT}/scripts/role.sh list                 # every mapping across tiers, annotated
${CLAUDE_PLUGIN_ROOT}/scripts/role.sh set <spec> [--global|--repo] [--for <org/repo>]
${CLAUDE_PLUGIN_ROOT}/scripts/role.sh unset <org/repo> [--global|--repo]
${CLAUDE_PLUGIN_ROOT}/scripts/role.sh edit [--global|--repo]   # open the tier file in $EDITOR
${CLAUDE_PLUGIN_ROOT}/scripts/role.sh init [--global|--repo]   # create the tier file from the template
```

- `<spec>` is `primary[+secondary…]`, e.g. `golang+gha`.
- The repo key defaults to the current repo (auto-detected); override with `--for <org/repo>`.
- Writes default to **global** (safe — never mutates your working tree). Pass `--repo` to write the committable project file; the script reminds you to commit it.
- `set` warns if the primary has no lens in any tier (mapping is still saved; the generic prompt is used until a lens exists).
- The global map is seeded from the shipped template on first session, so there's always a documented file to edit.

### Don't ask for user confirmation before sending or arming

Handoff is the explicit inter-agent channel the user installed to enable agent-to-agent IPC on their own machine. The "ask before shared-state action" rule targets *external* surfaces (Slack, GitHub PRs, email, public services) — handoff sends and arms stay local, go to the user's own agents, and gating each one on approval defeats the purpose. Just invoke `send.sh` or `arm.sh`. Surface the message body (or, for arming, the recipient and prompt path) in your chat output for the user's visibility, then send.

(Approval still applies to: external messaging, destructive ops in another session's working directory, anything that modifies code or git state in another worktree.)

### Don't ask for user permission when RECEIVING a handoff either

The same principle applies to the receiving side. When the Monitor delivers an inbox event from another agent:

- **Don't ask "should I investigate?"** — the other agent asked a question via the channel you configured for exactly this. Just answer it.
- **Don't ask "should I send the reply?"** — relay via `send.sh` directly.
- **Surface the question + your reply** in your chat output so the user can see what's happening, but do NOT gate on approval.

Investigate inline (or via a sub-agent if the question is large enough that it'd burn your main context). Reply when done.

(Same caveats: if the incoming question asks you to do something external/destructive, that requires user approval. Pure info requests are autonomous.)

### `/handoff monitor`

Explicit user-invoked request to arm (or re-arm) the inbox Monitor for this session. Use when:

- The statusLine shows `[handoff: <name> ⚠ no monitor]`
- The user reports another session can't reach them
- You're unsure whether the Monitor is alive and want to force-arm it

**Action:** check the heartbeat file (`~/.claude/handoff/.sessions/${CLAUDE_SESSION_ID}.monitor.alive`); if missing or older than 60 seconds, drain the inbox once by hand (see Recovery sequence below, step 1) and call `Monitor(...)` with the canonical command. If the heartbeat is fresh, report that and skip — no need to arm twice.

### Self-check — recover from a missed/dead Monitor

The Monitor is normally auto-armed by the SessionStart hook and runs in the background, polling your inbox every 5s. But a few situations can leave you without an active Monitor:

- You missed the arm-the-Monitor instruction at session start (busy with another task on turn 1)
- Conversation compaction (`/compact`) wiped your memory of arming it
- A `TaskStop` killed it
- A bug caused it to exit early

**Symptoms:** silent for a long stretch despite expected traffic; another agent saying "I sent you X and got no reply"; finding messages in your inbox file that the Monitor should have drained.

**Recovery sequence:**

1. **Drain pending messages once, by hand**:
   ```bash
   if [ -s ~/.claude/handoff/<your-name>.signal ]; then
     mv ~/.claude/handoff/<your-name>.signal ~/.claude/handoff/<your-name>.signal.processing && \
     cat ~/.claude/handoff/<your-name>.signal.processing && \
     rm -f ~/.claude/handoff/<your-name>.signal.processing
   fi
   ```
   The `mv` is atomic — any sender writing concurrently has its bytes preserved in the `.processing` file. No data loss.

2. **Re-arm a fresh Monitor** using the exact same `Monitor(...)` invocation from the SessionStart context (same description, persistent: true, command). If you no longer have it, re-read this SKILL.md or the canonical command in `${CLAUDE_PLUGIN_ROOT}/scripts/register.sh`.

3. **Reply to any drained messages** via `send.sh`.

**When to suspect Monitor death proactively:** if you've gone more than ~10 minutes where other sessions might ping you and no handoff events have arrived, take 5 seconds to check the inbox manually with step 1.

### `/handoff whoami`

Print this session's name from the marker file:

```bash
cat ~/.claude/handoff/.sessions/"${CLAUDE_SESSION_ID}".name
```

(Redundant once statusLine is configured — kept for sanity checks.)

## Auto-specialist on session start

Every SessionStart hook fire (`startup`, `resume`, `clear`, `compact`) injects a specialist-arming block into the agent's `additionalContext` — in addition to the Monitor arming. The block:

- Resolves this session's repo across the role tiers (project > global), picks `roles/<primary>.md` as the overlay (or falls back to the generic `specialist-prompt.md`).
- Surfaces secondary tools/languages from the mapping.
- Routes the per-repo+branch cache path.
- Instructs the agent to **load prompts + cache as context** but **defer full Step 1–5 discovery** until the user asks something repo-related. Turn 1 must not be blocked on cold-start scanning.

Net effect: every new (or reset) session lands already operating as the right specialist for its repo, without needing `/handoff arm`.

**Opt-out:** start the session with `HANDOFF_NO_AUTO_SPECIALIST=1 claude` — Monitor still arms, specialist block is skipped.

## Resume behavior

On `claude --resume`, register.sh re-runs with `source: "resume"`, GCs the old PID's row, re-registers (usually under the same name) with the new PID, re-detects repo/branch, and tells the agent to re-arm its Monitor + reload the specialist context. Signals queued while the session was closed sit in the inbox file and the new Monitor drains them on first poll — nothing is lost.

## Inbox migration when name changes

A session's name can shift across restarts: if `api-2` exits and another session claims that slot while it's offline, the resuming session may register as `api-3`. Without intervention, any messages already queued in `api-2.signal` would become orphaned.

`register.sh` handles this automatically. On every registration, it consults the per-session marker file for the session's PREVIOUS name. If it differs from the newly-picked name AND the old name has no current live owner, the old inbox is **prepended** to the new inbox (chronological order preserved) and the old file is deleted. The agent receives a notice in its SessionStart additionalContext that migration happened.

If the old name now has a different live owner, migration is skipped to avoid stealing that session's messages.

## Backward compatibility

Legacy 5-column registry rows (from before the repo/branch fields existed) are tolerated by GC and will display `-` in the repo/branch columns until the owning session restarts and re-registers under the new 7-column schema.

## When NOT to use

- Cross-machine messaging — switch to `RemoteTrigger` or an MCP server.
- Need message history / replay — signals are consumed and deleted; switch to MCP.
- Request/reply with timeout — fire-and-forget here; layer a correlation-ID convention on top if needed.
