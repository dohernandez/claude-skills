# handoff

Filesystem-based **agent-to-agent mailbox** for Claude Code sessions on the same machine. Bidirectional, ad-hoc, no daemon. Each session registers a name at start, watches its own inbox, and can message any other live session — plus auto-arms a per-repo "domain specialist" lens so cross-session questions get expert answers.

Use it when you're working in one session and want another (a different repo, worktree, or task) to take an action — without polluting either session's context with the other's work.

## Install

```
/plugin marketplace add dohernandez/claude-skills
/plugin install handoff@dohernandez-claude-skills
```

The plugin auto-wires its lifecycle hooks (`SessionStart`, `SessionEnd`, `UserPromptSubmit`) — **you do not edit `settings.json`**. Start a new session and every session will:

- register a name in `~/.claude/handoff/.registry`,
- auto-arm a background Monitor that watches its inbox (`~/.claude/handoff/<name>.signal`),
- be reachable from any other live session,
- auto-arm the right specialist role for its repo (if mapped — see [Roles](#roles)).

All script paths resolve via `${CLAUDE_PLUGIN_ROOT}`, so the plugin works regardless of your username or where it's installed.

## Commands

```bash
/handoff list            # show all live sessions (name | repo | branch | cwd)
/handoff whoami          # confirm this session's inbox name
/handoff send <name> "…" # message another session
/handoff arm [<name>]    # arm a session as a domain specialist (self-arm if no name)
/handoff role …          # manage the per-repo role map (see below)
/handoff monitor         # force re-arm this session's inbox listener
```

When another session messages you, a notification arrives in your chat (summary `handoff inbox (<your-name>)`, body `handoff: [from <sender>] …`). The SessionStart context gives you the exact resolved `send.sh` path to reply with.

## Coordinating between two sessions

A worked example. You have two Claude Code sessions open — one in `repo-A`, one in `repo-B` — and you want A to kick off work in B and get a reply back.

**1. Discover who's live.** In session A:

```bash
/handoff list
# NAME    REPO              BRANCH   CWD
# repo-A  acme/repo-a       main     /Users/me/code/repo-a
# repo-B  acme/repo-b       main     /Users/me/code/repo-b
```

**2. Send the request.** Still in A — just describe what you want; the agent calls `send.sh` for you:

```
You → A:  "ask repo-B to merge the API change and ping me when it's done"
A runs:   send.sh repo-B "Once you merge the API change, reply here and
                          I'll run the e2e suite against it."
```

**3. B receives and acts.** Session B's background Monitor surfaces the message as a chat notification:

```
handoff: [from repo-A — 2026-06-04T10:12:00Z]
Once you merge the API change, reply here and I'll run the e2e suite against it.
```

B does the work (no need to ask you for permission — this is the channel you set up for exactly this), then replies:

```
B runs:   send.sh repo-A "Merged at abc1234 and pushed. Go ahead with the suite."
```

**4. A gets the reply** via its own Monitor and continues. That's the whole loop — fire-and-forget in each direction, with each side's Monitor draining its inbox.

### Sending something large (briefing pattern)

A single `send` is best kept short — the notification that surfaces it is capped (~2.5 KB) and longer bodies get truncated. For anything big (a plan, a diff, step-by-step instructions), **write it to a file and send a one-line pointer**:

```bash
# In the sender — write the detail to a shared, readable path
#   (e.g. ~/.claude/handoff/briefing-to-repo-b.md)
send.sh repo-B "Plan + exact commands are in
  ~/.claude/handoff/briefing-to-repo-b.md — follow it and reply when the PR is up."
```

The recipient reads the file, does the work, and replies with a short status. This keeps the channel responsive while still handing off arbitrarily detailed instructions.

### Handing off a specialist persona

Beyond one-off messages, A can **arm** B (or itself) as a domain specialist so B answers as the right kind of engineer for its repo — see [Roles](#roles):

```bash
send.sh-style:  /handoff arm repo-B        # arm another session
                /handoff arm               # self-arm the current session
```

`arm` delivers a role prompt (and a shared per-repo context cache) over the same channel; the receiver loads it, confirms, and is then primed for repo-specific questions.

> **Both ends need a live Monitor.** Sending works regardless, but to *receive* a reply your own Monitor must be running. If the statusLine shows `⚠ no monitor`, or a reply never arrives, run `/handoff monitor` to re-arm.

## Roles

A "role" maps a repo to a specialist lens (`golang`, `rust`, `python`, `typescript`, `blockchain-ts`, `devops`, `lua`, …) so a session in that repo starts already operating as the right kind of engineer. Mappings are resolved across three tiers — **first match wins**:

| Tier | Location | Scope |
|---|---|---|
| Env | `$HANDOFF_ROLES_YAML` | one session (override) |
| **Project** | `<repo-root>/.claude/handoff/roles.yaml` | **everyone on that repo** (commit it) |
| Global | `~/.claude/handoff/roles.yaml` | you, across all repos |

The project tier is the killer feature: commit `.claude/handoff/roles.yaml` to a repo and **every teammate** who installs this plugin auto-gets the right role there — zero per-person config.

Manage the map without hand-editing YAML:

```bash
/handoff role show [<org/repo>]          # resolved role for a repo (+ which tier)
/handoff role list                       # every mapping across tiers, annotated
/handoff role set <spec> [--global|--repo] [--for <org/repo>]
/handoff role unset <org/repo> [--global|--repo]
/handoff role edit [--global|--repo]     # open the tier file in $EDITOR
/handoff role init [--global|--repo]     # create the tier file from the template
```

- `<spec>` is `primary[+secondary…]`, e.g. `golang+gha`.
- The repo key defaults to the current repo (auto-detected); override with `--for`.
- Writes default to **global** (safe — never mutates your working tree). Pass `--repo` to write the committable project file.
- On first run, your global map is seeded from [`roles.yaml.example`](./roles.yaml.example) so there's a documented file ready to edit.

Custom lenses layer too: a `roles/<name>.md` in your project or `~/.claude/handoff/roles/` overrides the shipped library lens of the same name. Unmapped repos fall back to the generic [`specialist-prompt.md`](./specialist-prompt.md).

Opt out of specialist auto-arming per session: `HANDOFF_NO_AUTO_SPECIALIST=1 claude` (the Monitor still arms).

## Optional: status line

A plugin cannot provide a `statusLine`, so this is **manual and optional**. To show your handoff session name in the bottom status line, add to your own `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh"
}
```

If `${CLAUDE_PLUGIN_ROOT}` isn't expanded in your `statusLine` context, use the absolute plugin install path (printed by `/plugin`) instead.

## How it works

```
~/.claude/handoff/
├── .registry              # name|repo|branch|cwd|pid|started_at|session_id  (one row per live session)
├── .lock.d/               # mkdir-based mutex for atomic registry edits
├── .sessions/
│   ├── <session_id>.name          # per-session name marker (read by whoami + statusline)
│   └── <session_id>.monitor.alive # Monitor heartbeat (freshness check)
├── roles.yaml             # your GLOBAL role map (seeded from the template)
├── specialist-cache/      # per-repo+branch context caches
└── <name>.signal          # inbox; written by send, drained by the recipient's Monitor
```

- **Names** default to the repo basename, auto-suffixed `-2`/`-3`/… on collision. Override with `HANDOFF_NAME=foo claude`.
- **Repo identity** comes from `git remote get-url origin`, so all worktrees of a repo resolve to the same logical repo. Override with `HANDOFF_REPO=…`.
- **Resilience**: on `--resume`, the session re-registers, migrates any inbox queued under a previous name, and re-arms its Monitor. Signals queued while a session was closed are drained on the next poll — nothing is lost.

## Limitations

- **Same machine only.** This is a local filesystem mailbox. For cross-machine messaging use `RemoteTrigger` or an MCP server.
- **No history/replay.** Signals are consumed and deleted on read.
- **Fire-and-forget.** No built-in request/reply with timeout; layer a correlation-ID convention on top if needed.

## Uninstall

```
/plugin uninstall handoff@dohernandez-claude-skills
```

Optionally remove leftover state: `rm -rf ~/.claude/handoff`. If you added the manual `statusLine`, remove that block from your `settings.json`.
