# Skill Infrastructure Groups

## Stop Hook Analysis

Only 3 skills need Stop hooks for **output validation**:

| Skill | Stop Hook Purpose |
|-------|-------------------|
| `commit` | Prevent commits to main, detect staged secrets |
| `create-skill` | Validate newly created skill files are valid |
| `pr-create` | Prevent AI attribution in PR title/body |

All other skills either validate during operation or don't need validation.

---

## Group 1: Requires `.claude/Taskfile.yaml` (5 skills)
Skills that call our Taskfile during operation:

| Skill | Usage |
|-------|-------|
| `developer` | `task -t .claude/Taskfile.yaml precommit` |
| `docs-refresh` | `task -t .claude/Taskfile.yaml skills-reference` |
| `setup` | `task -t .claude/Taskfile.yaml test` |
| `task` | `task -t .claude/Taskfile.yaml test/precommit` |
| `test` | Falls back to `task -t .claude/Taskfile.yaml test` |

## Group 2: Uses generic `task` commands (5 skills)
Skills that use user's own Taskfile:

| Skill | Usage |
|-------|-------|
| `bugfix` | `task test`, `task precommit` |
| `code` | `task lint`, `task format`, `task precommit` |
| `create-skill` | `task claude:validate-skill` (for validating created skills) |
| `tdd` | `task test`, `task precommit` |
| `workflow-setup` | `task setup` |

## Group 3: Standalone (12 skills)
Skills that can work without any infrastructure:

**With useful Stop hook (2):**
- `commit` - validates git state (no Taskfile needed)
- `pr-create` - validates no AI attribution (no Taskfile needed)

**No Stop hook needed (10):**
- `arch` - provides guidance only
- `debugger` - investigates only
- `deploy` - triggers external system
- `deploy-verify` - verification is its job
- `domain-expert` - provides knowledge only
- `linear` - Linear API validates
- `pr-merge` - gh validates CI
- `slack` - Slack API validates
- `workflow` - orchestrates other skills
- `workflow-finish` - git validates cleanup

---

## Action Items

1. Remove Stop hooks from skills that don't need them
2. Keep Stop hooks only for: `commit`, `create-skill`, `pr-create`
3. Update `commit` and `pr-create` validations to NOT require Taskfile (pure bash/git/gh)
4. `create-skill` needs Taskfile to validate created skills (acceptable)
