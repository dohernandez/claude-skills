---
name: workflow-setup
description: Setup development environment with git worktree for ticket-based workflows.
user-invocable: false
allowed-tools: [Read, Write, Edit, Bash, Glob, AskUserQuestion]
---

# Workflow Setup

## Purpose
Automate the development environment setup for worktree-based workflows. This skill is called by `workflow` during the "start" phase to create an isolated development environment for each ticket.

## When to Use

This skill is **not user-invocable**. It is called internally by the `workflow` skill when:
- Starting work on a new ticket (`/workflow start PROJ-123`)
- Creating an isolated worktree environment for a feature branch

## Quick Reference
- **Setup**: Run during framework wizard via `workflow` skill configure
- **Config**: `.claude/workflow-config.json`
- **Creates**: Git worktree, copies env files, installs deps, opens IDE
- **Requires**: Branch name from workflow
- **Output**: Worktree ready, pending-action.json for session handoff
- **Stop hook**: `task -t .claude/Taskfile.yaml validate-skill -- --skill workflow-setup`

## Configure Mode

Called during framework setup wizard (via `workflow` skill) to configure worktree preferences:

```
/workflow configure  # Includes workflow-setup configuration
```

**Discovers:**
- Preferred worktree base path
- IDE preference (Cursor, VSCode, WebStorm)
- Environment file copying preference

**Outputs:** `.claude/workflow-config.json`

```json
{
  "worktreeBasePath": "../worktrees/my-project",
  "ide": "Cursor",
  "copyEnvFiles": true
}
```

### Discovery Procedure

1. **Detect project name** from `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, or directory name
2. **Suggest worktree path** based on project name: `../worktrees/<project-name>`
3. **Detect installed IDEs** by checking for `cursor`, `code`, `webstorm` commands
4. **Propose configuration** to user for approval
5. **Save to** `.claude/workflow-config.json`

## What It Does

1. **Creates git worktree** at configured base path
2. **Copies `.env*` files** from source repo
3. **Installs dependencies** via auto-detected setup command
4. **Creates workflow directory** at `.claude/workflow/<branch>/`
5. **Copies plan** if `.claude/plan.md` exists in source
6. **Writes pending-action.json** for session handoff
7. **Opens IDE** with the worktree directory

## Configuration

Configured via `/workflow configure` during framework setup. Stored in `.claude/workflow-config.json`:

| Field | Description | Default |
|-------|-------------|---------|
| `worktreeBasePath` | Directory where worktrees are created | `../worktrees/<project>` |
| `ide` | IDE to open: `Cursor`, `WebStorm`, `VSCode` | Auto-detected |
| `copyEnvFiles` | Whether to copy `.env*` files | `true` |

## Workflow Directory Structure

Created in the new worktree at `.claude/workflow/<branch>/`:

```
.claude/workflow/<branch>/
├── plan.md              # Implementation plan (copied if exists)
├── context.json         # Ticket metadata, branch info
└── pending-action.json  # Handoff to next Claude session
```

### pending-action.json

Tells the new Claude session what to do:

```json
{
  "action": "continue-workflow",
  "phase": "review-plan",
  "ticketId": "PROJ-123",
  "branch": "feat/proj-123-add-feature",
  "message": "Workflow setup complete. Review the implementation plan and confirm to proceed.",
  "planFile": "plan.md",
  "createdAt": "2026-01-21T10:30:00Z"
}
```

### Phases

| Phase | Description | Next Action |
|-------|-------------|-------------|
| `review-plan` | Plan exists, needs review | Show plan, ask to confirm or modify |
| `create-plan` | No plan exists | Invoke developer to create plan |

## Procedure

### Step 1: Load Config

```
if .claude/workflow-config.json exists:
  load config
else:
  error: run `/workflow configure` first
```

Config is created during framework setup wizard via `/workflow configure`.

### Step 2: Update Base Branch

**CRITICAL**: Update main before creating worktree to avoid branching from stale code.

```bash
git fetch origin main
git checkout main
git pull origin main
```

### Step 3: Create Worktree

```bash
git worktree add <basePath>/<branch> -b <branch> main
```

### Step 4: Copy Environment Files

```bash
# Find and copy all .env* files
for file in .env*; do
  cp "$file" <worktree>/
done
```

### Step 5: Install Dependencies

```bash
cd <worktree>
# Auto-detect and run appropriate setup command
```

Detection order:
1. `.claude/setup-cache.yaml` → use cached `commands.setup`
2. `Taskfile.yaml` → `task setup` or `task install`
3. `Makefile` → `make setup` or `make install`
4. Auto-detect from project type:
   - `package.json` → `npm install`
   - `pyproject.toml` → `pip install -e .` or `poetry install`
   - `go.mod` → `go mod download`
   - `Cargo.toml` → `cargo build`

Run `/setup learn` first to cache the setup command for faster detection.

### Step 6: Create Workflow Directory

```bash
mkdir -p <worktree>/.claude/workflow/<branch>
```

### Step 7: Copy Plan (if exists)

```bash
if [ -f .claude/plan.md ]; then
  cp .claude/plan.md <worktree>/.claude/workflow/<branch>/plan.md
fi
```

### Step 8: Write Context and Pending Action

Write `context.json` with ticket metadata.
Write `pending-action.json` with phase based on whether plan exists.

### Step 9: Open IDE

| IDE | macOS Command |
|-----|---------------|
| WebStorm | `open -a "WebStorm" <path>` |
| Cursor | `cursor <path>` |
| VSCode | `code <path>` |

## Integration with workflow

This skill is called from `workflow` after branch name generation:

```
workflow start PROJ-123
  1. Detect source type (Linear)
  2. Fetch ticket details
  3. Safety checks
  4. Determine type (feat/fix/etc)
  5. Generate branch name
  6. >>> Call workflow-setup <<<
  7. --- HANDOFF to new Claude session ---
```

## Example Usage

Called internally by workflow:

```
/workflow start PROJ-123
  -> workflow generates branch: feat/proj-123-add-feature
  -> workflow-setup:
     - Creates worktree at .../my-project/proj-123-add-feature
     - Copies .env files
     - Runs setup command
     - Copies plan.md
     - Writes pending-action.json
     - Opens Cursor
  -> User sees new IDE window with worktree
  -> New Claude session reads pending-action.json
  -> Prompts: "Review the plan or start implementing?"
```
