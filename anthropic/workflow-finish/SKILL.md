---
name: workflow-finish
description: "Cleanup branch after PR is merged. Use when user says /workflow finish or /workflow-finish."
user-invocable: true
allowed-tools:
  - Bash
  - Glob
hooks:
  Stop:
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill workflow-finish"
---

# Workflow Finish

## Purpose

Cleanup git branches and worktrees after a PR is merged. Removes local branch, remote branch, worktree, and workflow context files.

## When to Use

- After a PR has been merged
- Cleaning up completed feature branches
- Removing stale worktrees and context files

## Quick Reference

- **Deletes**: Local branch, remote branch, worktree, workflow context
- **Requires**: Branch name, ticket ID, or current branch
- **Safe**: Verifies PR is merged before deleting

## Usage

```
/workflow-finish                              # Current branch
/workflow-finish feat/proj-123-some-feature   # Specify branch name
/workflow-finish PROJ-123                     # Specify ticket ID
```

## Procedure

### Step 1: Resolve Target Branch

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

# Search workflow directories
ls .claude/workflow/ | grep -i "<ticket-id>"
```

### Step 2: Verify PR is Merged

```bash
gh pr list --head <branch-name> --state all --json number,state,mergedAt
```

| State | Action |
|-------|--------|
| `MERGED` | Proceed to cleanup |
| `OPEN` | Warn: "PR not merged. Force finish anyway?" |
| `CLOSED` | Warn: "PR closed without merge. Force finish anyway?" |
| Not found | Warn: "No PR found. Force finish anyway?" |

### Step 3: Switch to Main (if on target branch)

```bash
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "<target-branch>" ]; then
  git checkout main
  git pull origin main
fi
```

### Step 4: Cleanup

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

### Step 5: Report

```
Workflow finished for `<branch-name>`

| Item | Status |
|------|--------|
| PR #<number> | ✓ Merged |
| Remote branch | ✓ Deleted / Already deleted |
| Local branch | ✓ Deleted |
| Worktree | ✓ Removed / None existed |
| Workflow context | ✓ Cleaned |
```

## Safety Rules

1. **Always verify PR is merged** before deleting branches
2. **Never force-finish without user confirmation** if PR is not merged
3. **Switch to main first** if currently on the branch being deleted
4. **Ignore errors** for already-deleted resources (idempotent)

## Examples

### Finish current branch
```
/workflow-finish
```
Uses current branch name.

### Finish by branch name
```
/workflow-finish feat/deploy-verify-service-registry
```

### Finish by ticket ID
```
/workflow-finish PROJ-123
```
Finds branch containing "proj-123" in the name.

## Automation

See `skill.yaml` for patterns.
See `sharp-edges.yaml` for common pitfalls.
