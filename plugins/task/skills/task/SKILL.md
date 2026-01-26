---
name: task
description: "Structured implementation process for features, chores, refactors, and docs. Use when implementing non-bugfix work."
user-invocable: false
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
hooks:
  Stop:
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill task"
---

# Task

## Purpose

Structured implementation methodology for non-bugfix work (features, chores, refactors, docs). Ensures work is properly scoped, planned, implemented with proper patterns, and verified before completion.

## When to Use

- Implementing new features
- Refactoring existing code
- Adding documentation
- Chore/maintenance tasks

## Quick Reference

- **Setup**: `/task configure` (run once during framework setup)
- **Usage**: Invoked by workflow skill for non-bugfix work
- **Update**: `/task learn <path>` (analyze specific patterns)

### Config Location

Config path depends on how the plugin was installed:

| Plugin Scope | Config File | Git |
|--------------|-------------|-----|
| **project** | `.claude/skills/task.yaml` | Committed (shared) |
| **local** | `.claude/skills/task.local.yaml` | Ignored (personal) |
| **user** | `.claude/skills/task.local.yaml` | Ignored (personal) |

**Precedence when reading** (first found wins):
1. `.claude/skills/task.local.yaml`
2. `.claude/skills/task.yaml`
3. Skill defaults

## Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| **configure** | `/task configure` | Auto-detect project structure, test patterns, architecture |
| **learn** | `/task learn <path>` | Learn patterns from specific directory |
| **execute** | Via workflow | Execute task phases (default) |

## Discovery Process

During `/task configure`:
1. Scan project structure for architecture patterns
2. Identify test framework and testing conventions
3. Detect code style and file organization
4. Find common patterns for each layer
5. Save to `.claude/skills/task.yaml`

## Phases Overview

- **Phases**: Scope → Plan → Implement → Verify
- **Key Rule**: Understand before building
- **Output**: Working implementation with tests passing

## Task Phases

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TASK WORKFLOW                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│   1. SCOPE   →   2. PLAN   →   3. IMPLEMENT   →   4. VERIFY                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Phase T1: Scope

**Goal:** Understand what needs to be done and define boundaries.

**Procedure:**
1. Read the ticket/request description carefully
2. Identify the core requirement (what must be delivered)
3. Identify out-of-scope items (what NOT to do)
4. Clarify any ambiguities with user
5. Document the scope

**Output:** Clear understanding of deliverables

```markdown
## Scope
- **Goal:** Add user notification system
- **Deliverables:**
  - New notification endpoint
  - Email/Slack integration
- **Out of scope:**
  - Notification history UI
  - User preferences dashboard
```

**Key Rule:** Don't start planning until scope is clear. Ask questions early.

## Phase T2: Plan

**Goal:** Design the approach before writing code.

**Procedure:**
1. Consult `/domain-expert` for domain understanding
2. Use `/arch` to map changes to architecture layers
3. Identify files to create/modify
4. Determine test strategy
5. Document the plan

**Output:** Implementation plan with files and approach

```markdown
## Plan
- **Domain:** Notifications (domain/notification/)
- **Layer:** Application service + Domain logic
- **Files to modify:**
  - src/domain/notification/service.ts (new)
  - src/application/handlers/notify.ts (add handler)
  - src/tests/notification.test.ts (new)
- **Approach:** Add event-driven notifications with pluggable channels
```

**Key Rule:** Get user approval on plan before implementing.

## Phase T3: Implement

**Goal:** Write code following project patterns.

**Procedure:**
1. Use `/developer` for code patterns and style
2. Follow TDD: write test first, then implementation
3. Work in small increments
4. Run tests frequently
5. Keep changes minimal and focused

**Guidelines:**
- Follow layer boundaries (see `/arch`)
- Use established patterns (see `/code`)
- Write tests alongside code (see `/tdd`)
- Don't over-engineer

**Output:** Working code with tests

**Key Rule:** Minimal changes only. Don't refactor unrelated code.

## Phase T4: Verify

**Goal:** Ensure implementation is complete and correct.

**Procedure:**
1. Run full test suite
2. Run pre-commit checks
3. Check IDE diagnostics for errors
4. Review changes against original scope
5. Verify no unintended side effects

**Output:** All tests pass, ready for commit

```bash
task -t .claude/Taskfile.yaml test       # All tests pass
task -t .claude/Taskfile.yaml precommit  # Lint + tests pass
```

**Key Rule:** Don't commit with failing tests or lint errors.

## Flow Diagram

```
┌─────────────────┐
│ /workflow start │
│ (type: feat)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ T1: SCOPE       │────►│ Unclear?        │
│ Understand req  │     │ Ask user        │
└────────┬────────┘     └─────────────────┘
         │ ✓ Clear
         ▼
┌─────────────────┐     ┌─────────────────┐
│ T2: PLAN        │────►│ Need approval   │
│ Design approach │     │ Show plan       │
└────────┬────────┘     └─────────────────┘
         │ ✓ Approved
         ▼
┌─────────────────┐     ┌─────────────────┐
│ T3: IMPLEMENT   │────►│ Issues?         │
│ Write code      │     │ Iterate         │
│ (uses /developer)│◄────│                 │
└────────┬────────┘     └─────────────────┘
         │ ✓ Complete
         ▼
┌─────────────────┐     ┌─────────────────┐
│ T4: VERIFY      │────►│ Tests fail?     │
│ Run tests       │     │ Fix and re-run  │
│                 │◄────│                 │
└────────┬────────┘     └─────────────────┘
         │ ✓ All pass
         ▼
┌─────────────────┐
│ Ready for       │
│ /commit         │
└─────────────────┘
```

## Task Context

Track progress in workflow context:

```json
{
  "type": "feat",
  "task": {
    "phase": "implement",
    "scopeConfirmed": true,
    "planApproved": true,
    "filesModified": ["src/domain/notification/service.ts"]
  }
}
```

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Start coding immediately | Scope and plan first |
| Plan in isolation | Get user approval on plan |
| Change unrelated code | Minimal changes only |
| Skip tests | Write tests with implementation |
| Ignore lint errors | Fix all errors before commit |

## Integration with Workflow

When `/workflow start` detects a non-fix ticket, it triggers this task flow:

1. `/workflow start` (feature ticket)
2. Workflow detects `type: feat` (or chore, refactor, docs)
3. Invokes task skill for phases T1-T4
4. After T4 passes: `/commit` → `/pr-create`

## Automation

See `skill.yaml` for patterns and procedures.
See `sharp-edges.yaml` for common implementation pitfalls.
