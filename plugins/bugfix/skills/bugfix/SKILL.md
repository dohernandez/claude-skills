---
name: bugfix
description: "Structured debugging process for bug fixes: reproduce, plan, failing test, fix, verify. Use when fixing bugs."
user-invocable: false
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# Bugfix

## Purpose

Structured debugging methodology for fixing bugs. Ensures bugs are properly understood before fixing, captured in tests to prevent regression, and fixed with minimal changes.

## Quick Reference

- **Phases**: Reproduce → Plan → Failing Test → Fix → Verify
- **Key Rule**: Never fix without a failing test
- **Output**: Minimal fix + test that prevents regression

## Bug Fix Phases

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              BUG FIX WORKFLOW                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│  1. REPRODUCE  →  2. PLAN  →  3. FAILING TEST  →  4. FIX  →  5. VERIFY          │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Phase B1: Reproduce the Bug

**Goal:** Confirm the bug exists and understand how to trigger it.

**Procedure:**
1. Read the ticket description and any error logs/screenshots
2. Identify the reproduction steps from the ticket
3. Execute reproduction steps in local environment
4. Document the observed behavior vs expected behavior
5. If cannot reproduce: ask user for more context, check environment differences

**Output:** Bug reproduction confirmed with clear steps

```markdown
## Bug Reproduction
- **Steps to reproduce:**
  1. ...
  2. ...
- **Expected:** ...
- **Actual:** ...
- **Environment:** <runtime version>, <os/platform>
```

**Key Rule:** Cannot proceed without reproduction. If you can't trigger the bug, you can't verify the fix.

## Phase B2: Plan (Root Cause + Fix)

**Goal:** Understand WHY the bug occurs and design the fix approach.

**Procedure:**
1. Trace the code path from reproduction steps
2. Read relevant source files
3. Form hypothesis about the cause
4. **If root cause is unclear:**
   - Add debug logging (logger.debug, NOT console.log)
   - Run with debug logs and analyze output
   - **Do NOT change implementation code yet**
5. Once root cause is identified, use `/developer` for code patterns
6. Design the minimal fix approach
7. **Get user approval on the fix plan**

**Debug Logging Pattern:**
```
# Add temporary debug logging to trace execution
# TypeScript: logger.debug('checkpoint', { var1, var2 });
# Python:     logger.debug(f"checkpoint: {var1=}, {var2=}")
# Go:         log.Printf("checkpoint: var1=%v var2=%v", var1, var2)
```

**Output:** Root cause identified + fix plan approved

```markdown
## Root Cause & Fix Plan
- **Location:** `<file>:<line>`
- **Cause:** Off-by-one error in array index comparison (uses `<` instead of `<=`)
- **Why it happens:** Edge case when index equals array length exactly
- **Fix:** Change `<` to `<=` in boundary comparison
- **Edge cases:** Empty array, single element, last element
```

**Key Rule:** Get user approval before proceeding. Never guess-and-fix.

## Phase B3: Write Failing Test

**Goal:** Capture the bug in a test that fails with current code.

**Procedure:**
1. Identify the appropriate test file (unit or regression)
2. Write a test that exercises the exact reproduction scenario
3. Run the test to confirm it **FAILS** (this is expected)
4. The test should fail for the **right reason** (the bug, not a typo)

**Output:** A failing test that documents the bug

```
# Write a test that exercises the exact bug scenario
# The test MUST fail before the fix is applied

# TypeScript/Jest:  it('should handle boundary', () => { expect(fn(edge)).toBe(expected); });
# Python/pytest:    def test_boundary(): assert fn(edge) == expected
# Go:               func TestBoundary(t *testing.T) { if got := fn(edge); got != want { t.Errorf(...) } }
```

**Key Rule:** Do NOT proceed to fixing until you have a failing test. The test is proof the bug exists and will prevent regression.

## Phase B4: Fix and Verify Test Passes

**Goal:** Implement the minimal fix that makes the failing test pass.

**Procedure:**
1. Make the **minimal change** to fix the root cause
2. Run the failing test - it should now **PASS**
3. If test still fails: re-analyze, your fix may be incomplete
4. Remove any temporary debug logging added in Phase B2

**Output:** Failing test now passes, debug logs removed

```
# Example: Off-by-one fix (language agnostic)
# Before (bug):  if index < length
# After (fix):   if index <= length
```

**Key Rule:** Minimal fix only. Do not refactor, clean up, or "improve" surrounding code. That's a separate task.

## Phase B5: Regression Testing

**Goal:** Ensure the fix doesn't break anything else.

**Procedure:**
1. Run full test suite (use project's configured test command)
2. If any tests fail:
   - Analyze if failure is related to the fix
   - If related: the fix may have unintended side effects, re-analyze
   - If unrelated: investigate separately (may be flaky test)
3. Run pre-commit checks (use project's configured precommit command)
4. All tests must pass before considering the bug fixed

**Output:** All tests pass, pre-commit succeeds

```bash
task test             # Run all tests
task precommit        # Run lint + tests
```

## Flow Diagram

```
┌─────────────────┐
│ Bug reported    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ B1: REPRODUCE   │────►│ Cannot reproduce│
│                 │     │ Ask for context │
└────────┬────────┘     └─────────────────┘
         │ ✓ Confirmed
         ▼
┌─────────────────┐     ┌─────────────────┐
│ B2: PLAN        │────►│ Unclear cause?  │
│ Root cause +    │     │ Add debug logs  │
│ fix approach    │◄────│ Re-analyze      │
│ (uses /developer)│     └─────────────────┘
└────────┬────────┘
         │ ✓ User approved
         ▼
┌─────────────────┐
│ B3: FAILING TEST│
│ Write test that │
│ captures bug    │
└────────┬────────┘
         │ ✓ Test fails
         ▼
┌─────────────────┐     ┌─────────────────┐
│ B4: FIX         │────►│ Test still fails│
│ Minimal change  │     │ Re-analyze fix  │
│                 │◄────│                 │
└────────┬────────┘     └─────────────────┘
         │ ✓ Test passes
         ▼
┌─────────────────┐     ┌─────────────────┐
│ B5: VERIFY      │────►│ Other tests fail│
│ Run all tests   │     │ Check side      │
│                 │◄────│ effects         │
└────────┬────────┘     └─────────────────┘
         │ ✓ All pass
         ▼
┌─────────────────┐
│ Ready for       │
│ /commit         │
└─────────────────┘
```

## Bug Fix Context

When working on a bug fix, track progress in workflow context:

```json
{
  "type": "fix",
  "bugfix": {
    "phase": "plan",
    "reproductionConfirmed": true,
    "rootCause": "Off-by-one in boundary comparison",
    "rootCauseLocation": "<file>:<line>",
    "planApproved": true,
    "failingTestFile": "<test-file>"
  }
}
```

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Jump straight to fixing | Reproduce first, plan the fix |
| Change code to debug | Add debug logs, analyze, then change |
| Fix without approval | Get user approval on fix plan |
| Fix + refactor together | Minimal fix only, refactor separately |
| Skip regression tests | Always run full test suite |
| Guess the root cause | Trace code path, add logs if unclear |

## Integration with Workflow

When `/workflow start` detects a bug ticket (via "bug" label or keywords), it triggers this bugfix flow:

1. `/workflow start PROJ-123` (bug ticket)
2. Workflow detects `type: fix`
3. Invokes bugfix skill for phases B1-B5
4. After B5 passes: `/commit` → `/pr-create`

## Automation

See `skill.yaml` for patterns and procedures.
See `sharp-edges.yaml` for common debugging pitfalls.
