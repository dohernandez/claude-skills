---
name: workflow
description: Manage development environment lifecycle for ticket-based work. Use when user says /workflow start, /workflow status, or /workflow finish.
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, mcp__linear-server__get_issue, mcp__linear-server__list_issues]
---

# Workflow

## Purpose
Manage the development environment lifecycle for ticket-based work. This skill handles setup (branch, worktree, context) and delegates implementation to `/bugfix` or `/task` based on ticket type.

## Quick Reference
- **Creates**: Feature branch, worktree, workflow context file
- **Requires**: Ticket source (Linear ID or plain text description)
- **Delegates to**: `/bugfix` (fix tickets) or `/task` (feat, chore, refactor, docs)

### Config Location

Config path depends on how the plugin was installed:

| Plugin Scope | Config File | Git |
|--------------|-------------|-----|
| **project** | `.claude/skills/workflow.yaml` | Committed (shared) |
| **local** | `.claude/skills/workflow.local.yaml` | Ignored (personal) |
| **user** | `.claude/skills/workflow.local.yaml` | Ignored (personal) |

**Precedence when reading** (first found wins):
1. `.claude/skills/workflow.local.yaml`
2. `.claude/skills/workflow.yaml`
3. Skill defaults

## When to Use

- Starting work on a new ticket or feature
- Beginning a bug fix from a ticket system (Linear)
- Creating an isolated worktree for development
- Completing work and cleaning up after PR merge

## Commands

| Command | Description |
|---------|-------------|
| `/workflow start <source>` | Setup branch/worktree, then delegate to bugfix or task |
| `/workflow configure` | Configure workflow preferences (worktree path, IDE) |
| `/workflow continue` | Resume pending workflow in new session |
| `/workflow status` | Show current workflow context and progress |
| `/workflow finish` | Cleanup branch after PR is merged |

**Related:** Use `/pr-merge` to merge PRs, `/deploy` to deploy after merge.

## Configure Mode

Configure workflow preferences during framework setup:

```
/workflow configure
```

**Discovers:**
- Worktree base path preference
- IDE preference (Cursor, VSCode, WebStorm)
- Environment file copying settings

**Outputs:** `.claude/workflow-config.json` (via workflow-setup)

This is typically run once during framework setup wizard.

## When to Start a Workflow

**Only start a new workflow when on `main` branch.**

| Current Branch | User Request | Action |
|----------------|--------------|--------|
| `main` | "fix this bug" | → `/workflow start` |
| `main` | "let's work on PROJ-123" | → `/workflow start PROJ-123` |
| `main` | "start a workflow for..." | → `/workflow start` |
| working branch | "fix this bug" | → Fix in current branch (no new workflow) |
| working branch | "let's work on this" | → Work in current branch (no new workflow) |
| working branch | "start a **new workflow** for..." | → `/workflow start` (explicit request) |

**Key Rules:**
- `main` is the only non-working branch
- Any branch other than `main` is a working branch
- If already on a working branch, continue working there unless user **explicitly** requests a new workflow
- Trigger phrases on `main`: "start a workflow", "let's work on...", "fix this issue...", or any code change task

## Session Continuation

After `/workflow start` opens the IDE with the new worktree, run this in the new Claude session:

```
/workflow continue
```

**What it does:**
1. Checks current branch name
2. Looks for `.claude/workflow/<branch>/pending-action.json`
3. If found, reads the pending action and context
4. Prompts user based on the type:
   - `fix` → Invoke `/bugfix` skill (B1: Reproduce)
   - `feat`/other → Invoke `/task` skill (T1: Scope)

**When to use:**
- After `/workflow start` opens a new IDE window
- Resuming work on a ticket in an existing worktree

## Phase 1: Start

```
/workflow start PROJ-123                     # From Linear ticket
/workflow start "Add user notifications"  # From plain text
```

**Pre-condition:** Must be on `main` branch (or user explicitly requested new workflow)

**Procedure:**
1. Detect source type (Linear ID pattern `XXX-###` vs plain text)
2. If Linear: fetch ticket details via MCP
3. Check for uncommitted changes (warn if present)
4. Determine branch type from context: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`
5. Generate branch name with type prefix:
   - Linear: `<type>/<ticket-id-lowercase>-<kebab-description>`
   - Plain text: `<type>/<kebab-description>`
6. **Call `workflow-setup`**:
   - Create git worktree at configured path
   - Copy `.env*` files to worktree
   - Install dependencies in worktree
   - Create `.claude/workflow/<branch>/` directory
   - Copy plan if `.claude/plan.md` exists
   - Write `pending-action.json` for session handoff
   - Open IDE with worktree
7. **Output next steps message** telling user to run `/workflow continue` in the new session
8. **--- HANDOFF: User opens new Claude session in IDE ---**
9. User runs `/workflow continue` to resume the workflow
10. **Delegate based on type:**
    - `fix` → Invoke `/bugfix` skill (5-phase debugging methodology)
    - `feat`/other → Invoke `/task` skill (4-phase implementation methodology)

## Task Delegation

Based on the ticket type detected in start:

| Type | Delegate To | Methodology |
|------|-------------|-------------|
| `fix` | `/bugfix` | B1: Reproduce → B2: Plan → B3: Failing Test → B4: Fix → B5: Verify |
| `feat` | `/task` | T1: Scope → T2: Plan → T3: Implement → T4: Verify |
| `chore` | `/task` | Same as feat |
| `refactor` | `/task` | Same as feat |
| `docs` | `/task` | Same as feat |

Both `/bugfix` and `/task` have a **Plan** phase (B2/T2) that:
- Uses `/developer` for code patterns
- Requires **user approval** before proceeding

## Retrospective (After Implementation)

After completing the implementation (feature or bug fix), capture learnings before committing:

**Procedure:**
1. Scan conversation for signals:
   - **Corrections** (high confidence): "No, don't use X, use Y"
   - **Rules** (high confidence): "Always do X", "Never do Y"
   - **Approvals** (medium): "Perfect!", "That's exactly right"
2. Route learnings to appropriate skill MEMORY.md files:
   - Testing patterns → `tdd/MEMORY.md`
   - Domain concepts → `domain-expert/MEMORY.md`
   - Architecture rules → `arch/MEMORY.md`
   - General code → `developer/MEMORY.md`

**Learning Quality Rules:**
- Must be actionable (DO/DON'T/USE/AVOID)
- Must be complete sentences, not fragments
- Must NOT be questions
- Must include WHY, not just WHAT

## Commit and PR

After retrospective, use the dedicated skills:

1. **Commit changes**: `/commit`
2. **Create PR**: `/pr-create`

These skills handle conventional commit messages, PR formatting, and CI validation.

## Phase 2: Status

```
/workflow status
```

**Shows:**
- Current branch and ticket info
- Implementation plan progress (or bug fix phase for type: fix)
- PR status (if created)

## Phase 3: Finish

```
/workflow finish
/workflow finish feat/proj-123-feature-name    # Explicit branch
```

**Pre-condition:** PR must be merged before finishing.

**Procedure:**
1. Resolve target branch (current branch or argument)
2. Verify PR is merged via `gh pr list --head <branch> --state merged`
3. Switch to main branch and pull latest
4. Remove worktree: `git worktree remove <path>`
5. Delete local branch: `git branch -D <branch>`
6. Clean up workflow context: `rm -rf .claude/workflow/<branch>/`
7. Report completion

See `workflow-finish` skill for detailed procedure and sharp edges.

## Workflow Context

Stored in `.claude/workflow-context.json` (gitignored):
```json
{
  "source": "linear",
  "ticketId": "PROJ-123",
  "title": "Add user notifications",
  "branch": "feat/proj-123-add-user-notifications",
  "type": "feat",
  "createdAt": "2026-01-21T...",
  "prUrl": null
}
```

## Branch Naming

Format: `<type>/<ticket-id-lowercase>-<kebab-description>` or `<type>/<kebab-description>`

Branch naming convention:
- Type prefix first (`feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, `test/`)
- Ticket ID in lowercase (if from Linear)
- Followed by kebab-case description from title

Examples:
- `feat/proj-123-add-user-notifications`
- `fix/proj-456-fix-date-parsing-error`
- `chore/eng-789-add-skill-for-claude-code-to-set-up-dev-environment`
- `feat/add-metrics-dashboard` (plain text, no ticket)

## Automation
See `skill.yaml` for the full procedure and patterns.
See `sharp-edges.yaml` for common failure modes.
