# Framework Files

This directory contains framework files that are installed alongside skills into target projects.

## Installation Structure

When the framework is installed into a target project:

```
target-project/
├── .claude/
│   ├── Taskfile.yaml              # ← From _framework/Taskfile.yaml
│   ├── scripts/                   # ← From _framework/scripts/
│   │   ├── validate-skill.sh
│   │   ├── check-skill-structure.sh
│   │   └── list-skills.sh
│   ├── hooks/                     # ← From _framework/hooks/
│   │   └── check-skill-structure.sh
│   ├── docs/                      # ← From _framework/docs/
│   │   └── git-workflow.md
│   ├── skills/                    # ← From anthropic/*/
│   │   ├── commit/
│   │   ├── arch/
│   │   └── ...
│   └── skills-config.yaml         # Wizard responses
├── .github/
│   └── PULL_REQUEST_TEMPLATE.md   # ← From _framework/github/ (if missing)
└── CLAUDE.md
```

## Configuration

During installation, the wizard asks for these commands (saved to `.claude/skills-config.env`):

| Variable | Description | Example |
|----------|-------------|---------|
| `PROJECT_NAME` | Project name (required) | `my-app` |
| `LINT_COMMAND` | Run linter (optional) | `npm run lint`, `task common:lint` |
| `TEST_COMMAND` | Run tests (optional) | `npm test`, `task common:test` |
| `PRECOMMIT_COMMAND` | Pre-commit validation (optional) | `task common:precommit` |

If `LINT_COMMAND` or `TEST_COMMAND` are not configured, those tasks will be skipped.

## Task Commands

After installation, use Task to run framework commands:

```bash
# Run project linter (uses LINT_COMMAND from config)
task -t .claude/Taskfile.yaml lint

# Run project tests (uses TEST_COMMAND from config)
task -t .claude/Taskfile.yaml test

# Run pre-commit checks (lint + test, or PRECOMMIT_COMMAND if set)
task -t .claude/Taskfile.yaml precommit

# Validate a specific skill
task -t .claude/Taskfile.yaml validate-skill -- --skill commit

# Check structure of all skills
task -t .claude/Taskfile.yaml check-structure

# List available skills
task -t .claude/Taskfile.yaml list-skills
```

### Including in Your Project Taskfile

You can also include the framework Taskfile in your project's Taskfile:

```yaml
# In your project's Taskfile.yaml
version: '3'

includes:
  claude:
    taskfile: .claude/Taskfile.yaml

# Now you can run:
# task claude:lint
# task claude:test
# task claude:validate-skill -- --skill commit
```

## How Stop Hooks Work

Each skill's SKILL.md has a Stop hook:

```yaml
---
name: commit
hooks:
  Stop:
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill commit"
---
```

When Claude Code finishes using the skill, it runs the Stop hook which:
1. Loads the skill's `validations.yaml`
2. Runs commands listed in `on_stop`
3. Reports pass/fail status

## Hooks

The framework includes Claude Code hooks installed to `.claude/hooks/`:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `check-skill-structure.sh` | PostToolUse (Write/Edit) | Validates skill files after editing |

The hook automatically validates skill structure when you edit files in `.claude/skills/`. It runs `task -t .claude/Taskfile.yaml claude:check-structure` and blocks if validation fails.

To enable, add to your `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/check-skill-structure.sh"
          }
        ]
      }
    ]
  }
}
```

## GitHub Templates

The framework provides default GitHub templates installed to `.github/` if the project doesn't already have them:

| Template | Purpose |
|----------|---------|
| `PULL_REQUEST_TEMPLATE.md` | Standard PR format with description, types of changes, checklist |

These templates are **only installed if missing** - existing templates are not overwritten.

## Scripts

The Taskfile wraps these scripts:

| Script | Purpose |
|--------|---------|
| `validate-skill.sh` | Run skill validations from validations.yaml |
| `check-skill-structure.sh` | Validate skill has required files, valid YAML |
| `list-skills.sh` | List available skills with descriptions |

Scripts are designed to be portable:
- No external dependencies required (yq optional)
- Works on macOS and Linux
- Bash 3.2+ compatible

## Requirements

- [Task](https://taskfile.dev/) must be installed
- Bash 3.2+
