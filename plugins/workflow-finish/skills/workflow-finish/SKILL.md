---
name: workflow-finish
description: "Cleanup branch after PR is merged. Use when user says /workflow finish or /workflow-finish."
user-invocable: true
allowed-tools:
  - Bash
  - Glob
  - Read
---

# Workflow Finish

## Purpose

Cleanup git branches and worktrees after a PR is merged. Removes local branch, remote branch, worktree, and workflow context files.

## When to Use

- After a PR has been merged
- Cleaning up completed feature branches
- Removing stale worktrees and context files

## Quick Reference

- **Setup**: `/workflow-finish configure` (or `/workflow configure` - shared config)
- **Usage**: `/workflow-finish` (uses saved config for worktree paths)
- **Config**: `.claude/workflow-config.json` (shared with workflow-setup)

## Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/workflow-finish configure` | Configure worktree preferences | Framework setup / wizard |
| `/workflow-finish` | Cleanup after PR merged | After PR is merged |
| `/workflow-finish <branch>` | Cleanup specific branch | Cleaning up specific branch |
| `/workflow-finish <ticket-id>` | Find and cleanup by ticket | Using ticket ID |

---

## Configure Mode

**When**: Framework setup wizard (one-time, shared with workflow-setup)

**What it does**:
1. Detects project name from package.json/pyproject.toml/etc.
2. Suggests worktree base path (where to find worktrees to clean)
3. Detects installed IDEs
4. Saves config to `.claude/workflow-config.json`

### Discovery Process

```
1. CHECK EXISTING CONFIG
   └─ If .claude/workflow-config.json exists, validate and confirm

2. DETECT PROJECT NAME
   ├─ package.json → name
   ├─ pyproject.toml → [project].name
   ├─ go.mod → module name
   └─ Fallback: directory name

3. SUGGEST WORKTREE PATH
   └─ Default: ../worktrees/<project-name>

4. PROPOSE TO USER
   └─ Show config, wait for approval
```

### Config Location

Skill config path depends on how the plugin was installed:

| Plugin Scope | Config File | Git |
|--------------|-------------|-----|
| **project** | `.claude/skills/workflow-finish.yaml` | Committed (shared) |
| **local** | `.claude/skills/workflow-finish.local.yaml` | Ignored (personal) |
| **user** | `.claude/skills/workflow-finish.local.yaml` | Ignored (personal) |

**Precedence when reading** (first found wins):
1. `.claude/skills/workflow-finish.local.yaml`
2. `.claude/skills/workflow-finish.yaml`
3. Skill defaults

**Note:** Runtime config is stored in `.claude/workflow-config.json` (shared with workflow-setup).

### Config Schema

```json
{
  "worktreeBasePath": "../worktrees/my-project",
  "ide": "Cursor",
  "copyEnvFiles": true
}
```

---

## Normal Usage

**Requires**: `.claude/workflow-config.json` exists (run configure first)

### Usage

```
/workflow-finish                              # Current branch
/workflow-finish feat/proj-123-some-feature   # Specify branch name
/workflow-finish PROJ-123                     # Specify ticket ID
```

### Workflow

```
1. LOAD CONFIG
   └─ Read worktreeBasePath from .claude/workflow-config.json

2. RESOLVE TARGET BRANCH
   ├─ No argument → current branch
   ├─ Ticket ID → search for matching branch
   └─ Branch name → use directly

3. VERIFY PR MERGED
   └─ gh pr list --head <branch> --state all

4. SWITCH TO MAIN (if on target branch)
   └─ git checkout main && git pull

5. CALCULATE WORKTREE PATH
   └─ <basePath>/<branch-without-type-prefix>

6. CLEANUP
   ├─ Remove worktree
   ├─ Delete remote branch
   ├─ Delete local branch
   └─ Remove workflow context

7. REPORT
   └─ Show summary table
```

---

## Procedure Details

### Step 1: Load Configuration

Read `.claude/workflow-config.json` to get `worktreeBasePath`.

If config doesn't exist:
```
Error: Configuration not found.
Run `/workflow-finish configure` or `/workflow configure` to configure.
```

### Step 2: Resolve Target Branch

| Input | Resolution |
|-------|------------|
| No argument | Use current branch (`git branch --show-current`) |
| Ticket ID (`XXX-###`) | Find branch containing that ticket ID |
| Branch name | Use directly |

**Finding branch from ticket ID:**
```bash
# Search worktrees
git worktree list | grep -i "<ticket-id>"

# Search local branches
git branch --list "*<ticket-id-lowercase>*"
```

### Step 3: Verify PR is Merged

```bash
gh pr list --head <branch-name> --state all --json number,state,mergedAt
```

| State | Action |
|-------|--------|
| `MERGED` | Proceed to cleanup |
| `OPEN` | Warn: "PR not merged. Force finish anyway?" |
| `CLOSED` | Warn: "PR closed without merge. Force finish anyway?" |
| Not found | Warn: "No PR found. Force finish anyway?" |

### Step 4: Calculate Worktree Path

```
worktreeBasePath = ../worktrees/my-project  (from config)
branch = feat/proj-123-add-feature
worktreePath = ../worktrees/my-project/proj-123-add-feature
```

### Step 5: Cleanup

```bash
# Remove worktree if exists
git worktree remove <worktree-path> --force 2>/dev/null || true

# Delete remote branch
git push origin --delete <branch-name> 2>/dev/null || echo "Remote branch already deleted"

# Delete local branch
git branch -D <branch-name> 2>/dev/null || echo "Local branch already deleted"

# Prune worktree refs
git worktree prune

# Remove workflow context directory
rm -rf .claude/workflow/<branch-name>/ 2>/dev/null || true
```

### Step 6: Report

```
Workflow finished for `<branch-name>`

| Item | Status |
|------|--------|
| PR #<number> | ✓ Merged |
| Worktree | ✓ Removed |
| Remote branch | ✓ Deleted |
| Local branch | ✓ Deleted |
| Workflow context | ✓ Cleaned |
```

## Safety Rules

1. **Always verify PR is merged** before deleting branches
2. **Never force-finish without user confirmation** if PR is not merged
3. **Switch to main first** if currently on the branch being deleted
4. **Ignore errors** for already-deleted resources (idempotent)
5. **Read worktree path from config** - don't hardcode paths

## Automation

See `skill.yaml` for patterns.
See `sharp-edges.yaml` for common pitfalls.
