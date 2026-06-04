# Claude Code Skills

Developer workflow skills for Anthropic's Claude Code. Install the full framework or individual skills via the marketplace.

## Overview

Skills are structured configuration files that guide AI assistants through complex operational procedures. They encode best practices, workflows, and domain knowledge that can be shared across projects.

## Quick Start

```bash
# 1. Add the marketplace (once)
/plugin marketplace add https://github.com/dohernandez/claude-skills.git

# 2. Install full framework (23 skills)
/plugin install framework@dohernandez-claude-skills

# 3. Initialize - REQUIRED (copies skills to your project)
claude --init

# 4. Configure - REQUIRED (sets up skills for your project)
/framework configure
```

After these steps, skills are available as `/commit`, `/tdd`, `/linear`, etc.

## Installation Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. /plugin marketplace add .../skills.git                  │
│                         ↓                                   │
│  2. /plugin install framework@dohernandez-claude-skills           │
│     (Plugin cached at ~/.claude/plugins/cache/)             │
│                         ↓                                   │
│  3. claude --init                                           │
│     (Setup hook copies skills to project/.claude/skills/)   │
│                         ↓                                   │
│  4. /framework configure                                    │
│     (Configure each skill that needs it)                    │
│                         ↓                                   │
│  Skills available as: /commit, /linear, /tdd, etc.          │
└─────────────────────────────────────────────────────────────┘
```

## Available Plugins (25)

Install the full framework or any individual skill:

| Plugin | Description |
|--------|-------------|
| `framework` | **All 23 skills** - Complete developer workflow |
| `arch` | Architecture patterns, layer boundaries, and structural validation |
| `bugfix` | Systematic bug investigation with root cause analysis |
| `code` | Code style enforcement and project conventions |
| `commit` | Git commits with conventional commit format |
| `create-skill` | Scaffold new Claude Code skills |
| `debugger` | Production issue debugging through logs and alerts |
| `deploy` | Deployment workflow with environment selection |
| `deploy-verify` | Post-deployment success verification |
| `developer` | Development orchestration with architecture awareness |
| `docs-refresh` | Generate and refresh documentation from source |
| `domain-expert` | Domain knowledge and business terminology |
| `handoff` | Agent-to-agent mailbox for same-machine Claude Code sessions ([guide](#agent-to-agent-communication-handoff)) |
| `linear` | Linear issue creation and management |
| `pr-create` | Create GitHub pull requests with standardized format |
| `pr-merge` | Merge pull requests with CI validation |
| `setup` | Project setup and environment configuration |
| `slack` | Slack notifications and team integrations |
| `task` | Task execution with validation checkpoints |
| `test` | Smart test runner with watch mode and coverage |
| `tdd` | Test-driven development: tests first, then code |
| `workflow` | Development workflow orchestration |
| `workflow-finish` | Cleanup branches and worktrees after PR merge |
| `workflow-setup` | Setup git worktree for ticket-based development |

**Same result:** Installing `framework` = Installing all 23 individual plugins

> `handoff` is a standalone runtime utility (it ships lifecycle hooks rather than a workflow skill), so it is **not** part of the `framework` bundle — install it on its own when you want inter-session messaging.

## Agent-to-Agent Communication (`handoff`)

The `handoff` plugin turns multiple Claude Code sessions running **on the same machine** into a small network that can message each other — useful when you have several sessions open across different repos or worktrees and want one to ask another to do something, without polluting either session's context.

```
/plugin install handoff@dohernandez-claude-skills
```

Installing wires the plugin's own `SessionStart` / `SessionEnd` / `UserPromptSubmit` hooks — **no `settings.json` edits**. Then every session, on start:

1. **Registers** itself in `~/.claude/handoff/.registry` with a name (the repo basename, auto-suffixed `-2`/`-3` on collision), its repo, and its branch.
2. **Arms a background Monitor** that polls its own inbox file (`~/.claude/handoff/<name>.signal`) every few seconds.

### Sending and receiving

```bash
/handoff list                       # see all live sessions: name | repo | branch | cwd
/handoff send <name> "your message" # deliver a message to another session's inbox
/handoff whoami                     # confirm this session's own name
```

The flow is a simple filesystem mailbox:

```
  session A                              session B
  /handoff send B "…"  ──writes──▶  ~/.claude/handoff/B.signal
                                          │
                                   B's Monitor polls, drains the file,
                                   surfaces it as a chat notification
                                          │
                                   B investigates, then:
                                   /handoff send A "reply"  ──▶  A's inbox
```

Messages are wrapped in a `[from <sender> — <timestamp>]` envelope, the sender is auto-derived, and the recipient is validated against the live registry — so a `send` to an unknown or dead session fails fast instead of going nowhere.

### Specialist roles (optional)

Beyond plain messaging, `handoff` can arm a session as a **domain specialist** for its repo so it answers cross-session questions as the right kind of engineer:

```bash
/handoff arm [<name>]               # arm a session (self-arm if no name) with a role prompt
/handoff role set golang+gha        # map the current repo to a role (auto-applied on session start)
/handoff role list                  # show the layered repo→role map (project > global)
```

Roles resolve across three tiers — env > project (`<repo>/.claude/handoff/roles.yaml`, committable & team-shared) > global (`~/.claude/handoff/roles.yaml`). Commit the project file and every teammate who installs `handoff` auto-gets the right role for that repo.

**Scope:** same machine only — it's a local filesystem mailbox, not a network service (for cross-machine use `RemoteTrigger` or an MCP server). Messages are consumed on read (no history/replay). Full reference: [`plugins/handoff/README.md`](plugins/handoff/README.md).

## Installation Options

### Option A: Install Full Framework (23 skills)

```bash
# 1. Add the marketplace (once)
/plugin marketplace add https://github.com/dohernandez/claude-skills.git

# 2. Install the framework plugin
/plugin install framework@dohernandez-claude-skills

# 3. Initialize - REQUIRED (copies skills to project)
claude --init

# 4. Configure - REQUIRED (configures all skills that need it)
/framework configure
```

**What gets installed:**
```
your-project/
├── .claude/
│   ├── skills/           # All 23 skills
│   │   ├── commit/
│   │   ├── linear/
│   │   ├── tdd/
│   │   └── ...
│   ├── hooks/            # Hook configurations
│   ├── scripts/          # Validation scripts
│   └── Taskfile.yaml     # Task runner
```

**Skills are invoked directly:** `/commit`, `/linear`, `/tdd`, etc.

### Option B: Install Individual Skills

```bash
# 1. Add the marketplace (if not already added)
/plugin marketplace add https://github.com/dohernandez/claude-skills.git

# 2. Install specific skill(s)
/plugin install commit@dohernandez-claude-skills
/plugin install tdd@dohernandez-claude-skills

# 3. Initialize - REQUIRED (copies skills to project)
claude --init

# 4. Configure - REQUIRED for skills that need it
/tdd configure
```

**What gets installed:**
```
your-project/
├── .claude/
│   └── skills/
│       ├── commit/
│       └── tdd/
```

**Skills are invoked directly:** `/commit`, `/tdd`

### Required Steps Summary

| Step | Command | When |
|------|---------|------|
| 1. Add marketplace | `/plugin marketplace add ...` | Once per machine |
| 2. Install plugin | `/plugin install <name>@...` | Once per project |
| 3. **Initialize** | `claude --init` | **REQUIRED** - Copies ALL skills to project |
| 4. **Configure** | `/framework configure` or `/skill configure` | **REQUIRED** - For skills marked with ✓ below |

**Important:**
- `claude --init` is required for ALL skills - it copies them from the plugin cache to your project
- Skills marked with ✓ in the Configure column below won't work properly without running `/skill configure`

## Framework Skills (23)

### Meta Skills (2)

| Skill | Configure | Description |
|-------|:---------:|-------------|
| `framework` | ✓ | Configure all skills at once |
| `create-skill` | | Scaffold new skills |

### Core Skills (12)

| Skill | Configure | Description |
|-------|:---------:|-------------|
| `commit` | | Git commits with conventional format |
| `pr-create` | | Create GitHub pull requests |
| `pr-merge` | | Merge pull requests with validation |
| `bugfix` | | Structured bug investigation |
| `task` | ✓ | Task execution and management |
| `test` | ✓ | Smart test runner with watch and coverage |
| `tdd` | ✓ | Test-driven development workflow |
| `workflow` | | Development workflow orchestrator |
| `workflow-setup` | ✓ | Initialize workflow with branch creation |
| `workflow-finish` | ✓ | Complete workflow with cleanup |
| `linear` | ✓ | Linear issue management (templates) |
| `slack` | | Slack integration |

### Customizable Skills (9)

| Skill | Configure | Description |
|-------|:---------:|-------------|
| `arch` | ✓ | Architecture guidance and validation |
| `code` | ✓ | Code style discovery and enforcement |
| `developer` | ✓ | Development orchestration |
| `docs-refresh` | ✓ | Documentation generation |
| `setup` | ✓ | Project setup and onboarding |
| `domain-expert` | ✓ | Domain knowledge and terminology |
| `debugger` | ✓ | Debug production issues |
| `deploy` | ✓ | Deployment workflow |
| `deploy-verify` | ✓ | Post-deployment verification |

## Configuration

### Configure All Skills

```bash
/framework configure
```

This wizard:
1. Asks for project settings (PROJECT_NAME, etc.)
2. Runs configure for each skill that needs it
3. Saves configs to `.claude/skills-config.env` and `.claude/skills/*.yaml`

### Configure Individual Skills

```bash
/tdd configure       # Configure TDD skill
/developer configure # Configure developer skill
/deploy configure    # Configure deploy skill
```

### Configuration Model

| Command | Purpose |
|---------|---------|
| `/skill configure` | Initial setup - scans project |
| `/skill learn` | Update config from new context |
| `/skill` | Normal usage with saved config |

## Repository Structure

```
skills/
├── .claude-plugin/
│   └── marketplace.json         # Marketplace catalog
│
├── plugins/                     # SOURCE OF TRUTH - Individual skill plugins
│   ├── commit/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── skills/
│   │   │   └── commit/          # ← Actual skill files here
│   │   │       ├── SKILL.md
│   │   │       └── skill.yaml
│   │   ├── hooks/hooks.json
│   │   └── scripts/setup.sh
│   ├── tdd/
│   ├── linear/
│   └── ... (22 framework skills + future standalone skills)
│
└── infra/                       # Infrastructure (Taskfiles, scripts, templates)
    ├── .claude-plugin/plugin.json
    ├── skills/                  # ← Symlinks to plugins/
    │   ├── commit → ../../plugins/commit/skills/commit
    │   ├── tdd → ../../plugins/tdd/skills/tdd
    │   └── ...
    ├── hooks/hooks.json
    ├── scripts/setup.sh
    └── Taskfile.yaml
```

**Key:** Skills are maintained in `plugins/`. Framework uses symlinks.

## Skill Architecture

Each skill directory contains:

| File | Required | Purpose |
|------|----------|---------|
| `SKILL.md` | Yes | Human-readable documentation |
| `skill.yaml` | Yes | Machine-readable procedure |
| `validations.yaml` | No | Automated checks |
| `sharp-edges.yaml` | No | Known edge cases |
| `collaboration.yaml` | No | Dependencies and triggers |

## Creating New Skills

```bash
/create-skill my-new-skill
```

Or manually:
1. Create directory: `.claude/skills/my-skill/`
2. Add `SKILL.md` with frontmatter
3. Add `skill.yaml` with procedure

## Requirements

- Claude Code CLI
- [Task](https://taskfile.dev/) (for framework infrastructure)
- Bash 3.2+ (macOS/Linux)

## License

MIT License - see LICENSE file for details.
