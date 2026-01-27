# Skill Infrastructure Groups

## Taskfile Split

| Taskfile | Purpose | Tasks | Needs Config? |
|----------|---------|-------|---------------|
| `Taskfile.yaml` | User commands | test, test:watch, test:coverage, lint, precommit | Yes |
| `Taskfile.skills.yaml` | Skill commands | validate-skill, check-structure, list-skills, audit-skills, skills-reference | No |

---

## Stop Hook Analysis

Only 1 skill needs a Stop hook:

| Skill | Stop Hook Purpose |
|-------|-------------------|
| `create-skill` | Validate newly created skill files |

All other skills validate during procedure (before action) or don't need validation.

---

## Skill Categories

### Standalone (16 skills)
No infrastructure needed - just copies skill files.

- `arch`
- `bugfix`
- `code`
- `commit`
- `debugger`
- `deploy`
- `deploy-verify`
- `domain-expert`
- `linear`
- `pr-create`
- `pr-merge`
- `slack`
- `tdd`
- `workflow`
- `workflow-finish`
- `workflow-setup`

### Skill Tasks Only (2 skills)
Downloads: `Taskfile.skills.yaml` + `scripts/`

| Skill | Tasks Used |
|-------|-----------|
| `create-skill` | validate-skill (Stop hook) |
| `docs-refresh` | skills-reference |

### User Tasks (4 skills)
Downloads: `Taskfile.yaml` + `Taskfile.skills.yaml` + `scripts/`

| Skill | Tasks Used |
|-------|-----------|
| `developer` | precommit |
| `setup` | test |
| `task` | test, precommit |
| `test` | test (fallback) |

---

## Configuration Persistence

Skills check if config already exists before prompting:
- If `.claude/skills-config.env` exists with TEST_COMMAND → don't ask again
- Only prompt for missing values

This means:
1. User installs `setup` → configures TEST_COMMAND, LINT_COMMAND
2. User installs `task` → detects config exists → skips configuration
