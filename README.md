# Claude Code Skills

Developer workflow skills for Anthropic's Claude Code. Install the full framework or individual skills via the marketplace.

## Overview

Skills are structured configuration files that guide AI assistants through complex operational procedures. They encode best practices, workflows, and domain knowledge that can be shared across projects.

## Quick Start

```bash
# 1. Add the marketplace (once)
/plugin marketplace add https://github.com/genlayerlabs/skills.git

# 2. Install full framework (22 skills)
/plugin install framework@genlayerlabs-skills

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
│  2. /plugin install framework@genlayerlabs-skills           │
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

## Available Plugins (23)

Install the full framework or any individual skill:

| Plugin | Description |
|--------|-------------|
| `framework` | **All 22 skills** - Complete developer workflow |
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
| `linear` | Linear issue creation and management |
| `pr-create` | Create GitHub pull requests with standardized format |
| `pr-merge` | Merge pull requests with CI validation |
| `setup` | Project setup and environment configuration |
| `slack` | Slack notifications and team integrations |
| `task` | Task execution with validation checkpoints |
| `tdd` | Test-driven development: tests first, then code |
| `workflow` | Development workflow orchestration |
| `workflow-finish` | Cleanup branches and worktrees after PR merge |
| `workflow-setup` | Setup git worktree for ticket-based development |

**Same result:** Installing `framework` = Installing all 22 individual plugins

## Installation Options

### Option A: Install Full Framework (22 skills)

```bash
# 1. Add the marketplace (once)
/plugin marketplace add https://github.com/genlayerlabs/skills.git

# 2. Install the framework plugin
/plugin install framework@genlayerlabs-skills

# 3. Initialize - REQUIRED (copies skills to project)
claude --init

# 4. Configure - REQUIRED (configures all skills that need it)
/framework configure
```

**What gets installed:**
```
your-project/
├── .claude/
│   ├── skills/           # All 22 skills
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
/plugin marketplace add https://github.com/genlayerlabs/skills.git

# 2. Install specific skill(s)
/plugin install commit@genlayerlabs-skills
/plugin install tdd@genlayerlabs-skills

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
| 3. **Initialize** | `claude --init` | **REQUIRED** - Copies skills to project |
| 4. **Configure** | `/framework configure` or `/skill configure` | **REQUIRED** - For skills that need it |

**Important:** Without `claude --init`, skills won't be copied to your project. Without configure, skills that require configuration won't work properly.

## Framework Skills (22)

### Meta Skills (2)

| Skill | Configure | Description |
|-------|-----------|-------------|
| `framework` | yes | Configure the framework |
| `create-skill` | no | Scaffold new skills |

### Core Skills (11)

| Skill | Configure | Description |
|-------|-----------|-------------|
| `commit` | no | Git commits with conventional format |
| `pr-create` | no | Create GitHub pull requests |
| `pr-merge` | no | Merge pull requests with validation |
| `bugfix` | no | Structured bug investigation |
| `task` | yes | Task execution and management |
| `tdd` | yes | Test-driven development workflow |
| `workflow` | no | Development workflow orchestrator |
| `workflow-setup` | yes | Initialize workflow with branch creation |
| `workflow-finish` | yes | Complete workflow with cleanup |
| `linear` | no | Linear issue management |
| `slack` | no | Slack integration |

### Customizable Skills (9)

| Skill | Configure | Description |
|-------|-----------|-------------|
| `arch` | no | Architecture guidance and validation |
| `code` | no | Code style discovery and enforcement |
| `developer` | yes | Development orchestration |
| `docs-refresh` | yes | Documentation generation |
| `setup` | no | Project setup and onboarding |
| `domain-expert` | no | Domain knowledge and terminology |
| `debugger` | yes | Debug production issues |
| `deploy` | yes | Deployment workflow |
| `deploy-verify` | yes | Post-deployment verification |

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
└── framework/                   # Framework plugin (bundles all skills)
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
