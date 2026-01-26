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
│   │   ├── check-skill-yaml.sh
│   │   ├── audit-skills.sh
│   │   ├── list-skills.sh
│   │   └── generate-skills-reference.sh
│   ├── hooks/                     # ← From _framework/hooks/
│   │   └── check-skill-structure.sh
│   ├── docs/                      # ← From _framework/docs/
│   │   └── git-workflow.md
│   ├── skills/                    # ← From anthropic/*/
│   │   ├── commit/
│   │   ├── arch/
│   │   └── ...
│   └── skills-config.env          # Wizard responses
├── .github/
│   └── PULL_REQUEST_TEMPLATE.md   # ← From _framework/github/ (if missing)
└── Taskfile.yaml                  # (optional) Include framework tasks
```

## Configuration Model

Skills follow a **configure/learn** pattern:

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/skill configure` | Initial setup - scans project, proposes config | Framework install, updates |
| `/skill learn` | Update config from new context | When project changes |
| `/skill` | Normal usage with saved config | Daily use |

### Framework-Level Config

During installation, the wizard asks for these settings (saved to `.claude/skills-config.env`):

| Variable | Description | Example |
|----------|-------------|---------|
| `PROJECT_NAME` | Project name (required) | `my-app` |
| `LINT_COMMAND` | Run linter (optional) | `npm run lint`, `task lint` |
| `TEST_COMMAND` | Run tests (optional) | `npm test`, `task test` |
| `PRECOMMIT_COMMAND` | Pre-commit validation (optional) | `task precommit` |

If `LINT_COMMAND` or `TEST_COMMAND` are not configured, those tasks will be skipped.

### Skill-Level Config

Each skill that supports `/skill configure` saves its config to `.claude/skills/<skill>.yaml`:

```yaml
# .claude/skills/tdd.yaml
version: 1
discovered_at: "2024-01-26T10:00:00Z"

test_framework: vitest
test_locations:
  - "src/**/*.test.ts"
assertion_style: expect
```

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

# Audit all skills
task -t .claude/Taskfile.yaml audit-skills

# Check structure of all skills
task -t .claude/Taskfile.yaml check-structure

# List available skills
task -t .claude/Taskfile.yaml list-skills

# Generate skills reference documentation
task -t .claude/Taskfile.yaml skills-reference
```

### Including in Your Project Taskfile

You can also include the framework Taskfile in your project's Taskfile:

```yaml
# In your project's Taskfile.yaml
version: '3'

includes:
  claude:
    taskfile: .claude/Taskfile.yaml

dotenv: ['.claude/skills-config.env', '.env']

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

The hook automatically validates skill structure when you edit files in `.claude/skills/`. It runs `task -t .claude/Taskfile.yaml check-structure` and blocks if validation fails.

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
| `check-skill-yaml.sh` | CI check for YAML structure and required files |
| `audit-skills.sh` | Semantic skill audit (multi-YAML pattern compliance) |
| `list-skills.sh` | List available skills with descriptions |
| `generate-skills-reference.sh` | Generate skills reference documentation |

Scripts are designed to be portable:
- No external dependencies required (yq optional)
- Works on macOS and Linux
- Bash 3.2+ compatible

## Requirements

- [Task](https://taskfile.dev/) must be installed
- Bash 3.2+
