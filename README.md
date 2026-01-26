# Claude Code Skills Framework

Reusable skills for AI coding assistants, specifically designed for Anthropic's Claude Code.

## Overview

Skills are structured configuration files that guide AI assistants through complex operational procedures. They encode best practices, workflows, and domain knowledge that can be shared across projects.

## Installation

### Install Full Framework (21 skills)

```bash
/marketplace add genlayerlabs/skills/anthropic/framework
```

This installs:
- All 21 framework skills
- Framework infrastructure (Taskfile, scripts, hooks)
- Runs installation wizard for project configuration

### Install Individual Skill

```bash
/marketplace add genlayerlabs/skills/anthropic/commit
```

Installs:
- The specified skill
- Minimal framework dependencies (Taskfile, validation scripts)
- Runs `/commit configure` if skill requires configuration

### Install Standalone Skill

```bash
/marketplace add genlayerlabs/skills/anthropic/node-installer
```

Installs:
- The standalone skill (not part of framework bundle)
- Runs `/node-installer configure` if skill requires configuration

## Installation Behavior

| Command | What Gets Installed | Configure Runs |
|---------|---------------------|----------------|
| `.../anthropic/framework` | _framework/ + 21 skills | Framework wizard + all skills with `configure: true` |
| `.../anthropic/commit` | commit/ + minimal deps | `/commit configure` (if skill has configure) |
| `.../anthropic/node-installer` | node-installer/ only | `/node-installer configure` (if skill has configure) |

**Key principle:** Any skill with `configure: true` in the manifest will run its configure step on install, ensuring consistent behavior whether installed as part of the framework or individually.

## Post-Installation: Configure/Re-Configure

You can run or re-run configuration at any time:

```bash
# Run framework wizard
/framework configure

# Configure/re-configure individual skills
/tdd configure
/arch configure
/commit configure
```

## Framework Skills (21)

### Core Skills (12) - Drop-in, no customization needed

| Skill | Command | Description |
|-------|---------|-------------|
| `commit` | `/commit` | Git commit with conventional commit format |
| `pr-create` | `/pr-create` | Create pull requests with standardized format |
| `pr-merge` | `/pr-merge` | Merge pull requests with proper validation |
| `bugfix` | `/bugfix` | Structured bug investigation and fix workflow |
| `task` | `/task` | Task execution and management workflow |
| `tdd` | `/tdd` | Test-driven development workflow |
| `workflow` | `/workflow` | Main development workflow orchestrator |
| `workflow-setup` | `/workflow-setup` | Initialize workflow with branch creation |
| `workflow-finish` | `/workflow-finish` | Complete workflow with cleanup |
| `create-skill` | `/create-skill` | Create new skills following the architecture |
| `linear` | `/linear` | Linear issue management and ticket workflows |
| `slack` | `/slack` | Slack integration for notifications |

### Customizable Skills (9) - Have `/skill configure` mode

| Skill | Command | Description |
|-------|---------|-------------|
| `arch` | `/arch` | Architecture guidance and validation |
| `code` | `/code` | Code style configuration and enforcement |
| `developer` | `/developer` | Development orchestration with domain understanding |
| `docs-refresh` | `/docs-refresh` | Documentation generation and maintenance |
| `setup` | `/setup` | Project setup and onboarding |
| `domain-expert` | `/domain` | Domain knowledge and terminology |
| `debugger` | `/debugger` | Debugging workflow with systematic investigation |
| `deploy` | `/deploy` | Deployment workflow |
| `deploy-verify` | `/deploy-verify` | Post-deployment verification |

## Configuration Model

Skills follow a **configure/learn** pattern for project-specific setup:

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/skill configure` | Initial setup - scans project, proposes config | Framework install, updates |
| `/skill learn` | Update config from new context | When project changes |
| `/skill` | Normal usage with saved config | Daily use |

### Example: TDD Skill

```
# First time setup (during framework install)
/tdd configure
  → Scans project for test patterns
  → Proposes config (framework, locations, assertions)
  → Saves to .claude/skills/tdd.yaml

# Later, after adding new test patterns
/tdd learn
  → Updates config with new patterns

# Normal usage
/tdd
  → Uses saved config for consistent TDD workflow
```

### Config Files

Each skill saves its config to `.claude/skills/<skill>.yaml`:

```yaml
# .claude/skills/tdd.yaml
version: 1
configured_at: "2024-01-26T10:00:00Z"

test_framework: vitest
test_locations:
  - "src/**/*.test.ts"
  - "tests/**/*.spec.ts"
assertion_style: expect
```

## Installation Structure

After installing the framework, your project has:

```
your-project/
├── .claude/
│   ├── Taskfile.yaml              # Framework task runner
│   ├── skills-config.env          # Framework config (PROJECT_NAME, etc.)
│   ├── scripts/                   # Validation scripts
│   │   ├── validate-skill.sh
│   │   ├── check-skill-structure.sh
│   │   ├── audit-skills.sh
│   │   └── ...
│   ├── hooks/                     # Claude Code hooks
│   │   └── check-skill-structure.sh
│   └── skills/                    # All 21 skills
│       ├── commit/
│       │   ├── SKILL.md
│       │   ├── skill.yaml
│       │   └── validations.yaml
│       ├── arch/
│       │   ├── SKILL.md
│       │   ├── skill.yaml
│       │   └── arch.yaml          # ← Config from /arch configure
│       └── ...
├── .github/
│   └── PULL_REQUEST_TEMPLATE.md   # PR template
└── Taskfile.yaml                  # (optional) Include framework tasks
```

## Framework Configuration

During installation, the wizard asks for project-level settings saved to `.claude/skills-config.env`:

| Variable | Description | Example |
|----------|-------------|---------|
| `PROJECT_NAME` | Project name (required) | `my-app` |
| `LINT_COMMAND` | Run linter (optional) | `npm run lint` |
| `TEST_COMMAND` | Run tests (optional) | `npm test` |
| `PRECOMMIT_COMMAND` | Pre-commit validation (optional) | `task precommit` |

## Task Commands

After installation, use Task to run framework commands:

```bash
# Run project linter
task -t .claude/Taskfile.yaml lint

# Run project tests
task -t .claude/Taskfile.yaml test

# Run pre-commit checks
task -t .claude/Taskfile.yaml precommit

# Validate a specific skill
task -t .claude/Taskfile.yaml validate-skill -- --skill commit

# Audit all skills
task -t .claude/Taskfile.yaml audit-skills

# List available skills
task -t .claude/Taskfile.yaml list-skills
```

### Include in Your Taskfile

```yaml
# Taskfile.yaml
version: '3'

includes:
  claude:
    taskfile: .claude/Taskfile.yaml

dotenv: ['.claude/skills-config.env', '.env']

# Now use: task claude:lint, task claude:validate-skill, etc.
```

## Skill Architecture

Each skill directory contains:

| File | Required | Purpose |
|------|----------|---------|
| `SKILL.md` | Yes | Human-readable documentation with frontmatter |
| `skill.yaml` | Yes | Machine-readable procedure definition |
| `validations.yaml` | No | Automated checks (on_stop, on_warn) |
| `sharp-edges.yaml` | No | Known edge cases to check proactively |
| `collaboration.yaml` | No | Dependencies and trigger patterns |

### SKILL.md Frontmatter

```yaml
---
name: commit
description: "Create git commits with conventional commit messages."
user-invocable: true
allowed-tools:
  - Read
  - Bash
  - Glob
hooks:
  Stop:
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill commit"
---
```

### skill.yaml Structure

```yaml
name: commit
kind: action          # action, workflow, methodology, utility, integration
version: "2.0.0"
description: "..."

purpose: |
  What this skill does and why.

  Configuration model:
  - /skill configure: Initial setup
  - /skill learn: Update from context
  - /skill: Normal usage

config_location: ".claude/skills/commit.yaml"

commands:
  - name: configure
    description: "Initial setup"
    procedure: [...]

  - name: learn
    description: "Update config"
    procedure: [...]

procedure:
  - step: "Step 1"
    detail: "What to do"
    commands: ["cmd1", "cmd2"]

patterns:
  - id: pattern-name
    description: "..."

anti_patterns:
  - id: anti-pattern-name
    description: "..."
    why_bad: "..."
```

## Creating New Skills

Use the `create-skill` skill:

```
/create-skill my-new-skill
```

Or manually:

1. Create directory: `.claude/skills/my-skill/`
2. Add `SKILL.md` with frontmatter
3. Add `skill.yaml` with procedure
4. Add `validations.yaml` (optional)
5. Run `task -t .claude/Taskfile.yaml audit-skills` to validate

## Standalone Skills

Skills not part of the framework bundle (install individually):

| Skill | Command | Description |
|-------|---------|-------------|
| (none yet) | | Add standalone skills as needed |

## Requirements

- [Task](https://taskfile.dev/) must be installed
- Bash 3.2+ (macOS/Linux)
- Claude Code CLI

## License

MIT License - see LICENSE file for details.
