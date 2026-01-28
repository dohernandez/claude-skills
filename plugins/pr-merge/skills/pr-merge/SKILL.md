---
name: pr-merge
description: Merge GitHub pull requests with strict CI validation. Never bypasses failed checks. Use when merging PRs or when user says /pr-merge.
user-invocable: true
allowed-tools: [Bash, Read]
---

# PR Merge

## Purpose
Merge GitHub pull requests with strict CI validation and merge state checking.
Enforces the rule: **NEVER bypass failed CI checks**. Only offers bypass for missing reviews when all checks pass.

## Quick Reference
- **Setup**: `/pr-merge configure` (set merge strategy and branch cleanup)
- **Usage**: `/pr-merge` or `/pr-merge <number>`
- **Config**: Depends on installation model (see Save Location)
- **Requires**: GitHub CLI installed and authenticated, PR exists for branch

## Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/pr-merge configure` | Set merge strategy and branch cleanup | First time in a project |
| `/pr-merge` | Merge PR for current branch | Normal usage |
| `/pr-merge <number>` | Merge specific PR by number | When not on the PR branch |

---

## /pr-merge configure

**When**: First time using `/pr-merge` in a project, or to change merge preferences

**What it does**:
1. Asks user for preferred merge strategy (squash, merge, rebase)
2. Asks whether to delete branch after merge
3. Saves config to yaml (installation-model-aware path)

### Workflow

```
1. ASK MERGE STRATEGY
   └─ squash (default), merge, or rebase?

2. ASK BRANCH CLEANUP
   └─ Delete branch after merge? (default: true)

3. SAVE CONFIG
   └─ Write pr-merge.yaml with preferences
```

### Save Location

Config path depends on the installation model. Detect which model is active by checking whether this skill is running from inside `.claude/skills/pr-merge/` (my-workflow) or from an external plugin directory (standalone).

| Installation Model | Config File | How to Detect |
|--------------------|-------------|---------------|
| **Standalone** (external plugin) | `.claude/skills/pr-merge.yaml` | Skill files are NOT inside `.claude/skills/pr-merge/` |
| **my-workflow** (copied into project) | `.claude/skills/pr-merge/pr-merge.yaml` | Skill files ARE inside `.claude/skills/pr-merge/` |

**Precedence when reading** (first found wins):
1. `.claude/skills/pr-merge/pr-merge.yaml` (my-workflow installation)
2. `.claude/skills/pr-merge.yaml` (standalone installation)
3. Skill defaults

### Config Schema

```yaml
# .claude/skills/pr-merge.yaml (standalone installation)
# .claude/skills/pr-merge/pr-merge.yaml (my-workflow installation)
version: 1
configured_at: "ISO timestamp"
merge:
  strategy: "squash"       # squash | merge | rebase
  delete_branch: true      # delete remote branch after merge
```

---

## /pr-merge (Normal Usage)

**When**: Merging a pull request

**Reads config from** (first found):
1. `.claude/skills/pr-merge/pr-merge.yaml` (my-workflow installation)
2. `.claude/skills/pr-merge.yaml` (standalone installation)
3. Skill defaults (squash, delete branch)

## Critical Rule

**NEVER offer to bypass failed CI checks.**

Failed checks mean broken code. The only acceptable bypass is for missing review when ALL checks pass.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│   All checks pass + CLEAN        → Auto-merge                               │
│   All checks pass + BEHIND       → Update branch, re-check                  │
│   All checks pass + BLOCKED      → Ask: "Bypass review?"                    │
│   Any check FAILED               → STOP. Investigate failure.               │
│   Conflicts (DIRTY)              → Cannot auto-merge                        │
│   Checks still running           → Wait and re-check                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Merge Flow

### Step 1: Get PR

```bash
# If PR number provided, use it
gh pr view 123 --json state,mergeable,mergeStateStatus,statusCheckRollup

# Otherwise, find PR for current branch
gh pr list --head $(git branch --show-current) --json number,state
```

### Step 2: Check PR State

| State | Action |
|-------|--------|
| `MERGED` | "PR already merged" - done |
| `CLOSED` | "PR is closed" - stop |
| `OPEN` | Continue to CI check |

### Step 3: Check CI Status

For each check in `statusCheckRollup`:

| Status | Action |
|--------|--------|
| `IN_PROGRESS` | Wait 30s, retry (max 5 retries) |
| `FAILURE` | **STOP. Display failed check name. Investigate.** |
| `SUCCESS` | Continue |

**CRITICAL**: On FAILURE, do NOT offer to bypass. Say:
> "CI check '<name>' failed. Please investigate before merging."

### Step 4: Check Merge State

| mergeStateStatus | Action |
|------------------|--------|
| `CLEAN` | Proceed to merge |
| `BEHIND` | Update branch, re-check CI |
| `BLOCKED` | If all checks pass → ask "Bypass review?" |
| `DIRTY` | "Conflicts detected. Resolve before merging." |

### Step 5: Execute Merge

```bash
# Uses configured strategy (default: squash)
gh pr merge <number> --squash --delete-branch
```

## Update Behind Branch

When `mergeStateStatus` is `BEHIND`:

```bash
git fetch origin main
git merge origin/main --no-edit
git push
# Then re-check from Step 3
```

## Automation
See `skill.yaml` for the full procedure and patterns.
See `sharp-edges.yaml` for common failure modes.
