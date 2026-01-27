---
name: tdd
description: "Enforce TDD discipline: tests first, fix code not tests. Use when user says /tdd or /test."
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# TDD

## Purpose

Enforce Test-Driven Development discipline. All changes must have tests written first, tests must fail before implementation, and when tests fail, fix the code not the tests.

## Quick Reference

- **Setup**: `/tdd configure` (run once during framework setup)
- **Usage**: `/tdd` (uses saved config)
- **Update**: `/tdd learn <path>` (analyze specific path)
- **Config**: `.claude/skills/tdd.yaml`

## Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/tdd configure` | Analyze entire project for test patterns | Framework setup / wizard |
| `/tdd learn <path>` | Analyze specific path, update config | New module added |
| `/tdd` | Write tests using saved patterns | Normal development |

---

## /tdd configure

**When**: Framework setup wizard (one-time)

**What it does**:
1. Scans entire project for testing patterns
2. Proposes findings to user
3. User approves/modifies
4. Saves to `.claude/skills/tdd.yaml`

### Discovery Process

```
1. DETECT TEST FRAMEWORK
   ├─ JavaScript/TypeScript: package.json → jest, vitest, mocha, ava
   ├─ Python: pyproject.toml, requirements.txt → pytest, unittest
   ├─ Go: *_test.go files → go test
   └─ Rust: Cargo.toml → cargo test

2. FIND TEST LOCATIONS
   ├─ Co-located: src/**/*.test.ts
   ├─ Separate: tests/, __tests__/, test/
   └─ Pattern: *.test.*, *_test.*, test_*

3. ANALYZE TEST STRUCTURE (read 5-10 test files)
   ├─ Organization: describe/it, class-based, function-based
   ├─ Assertion style: expect, assert, require
   ├─ Mock patterns: vi.fn(), jest.mock(), @patch, etc.
   └─ Fixture patterns: beforeEach, fixtures/, conftest.py

4. DETECT TEST COMMANDS
   ├─ Taskfile.yaml: task test, task test:unit
   ├─ package.json: npm test, npm run test:*
   ├─ Makefile: make test
   └─ Direct: pytest, go test, cargo test
```

### Proposal Format

```yaml
# Proposed TDD Configuration
# Review and approve to save to .claude/skills/tdd.yaml

framework: vitest
language: typescript

test_locations:
  pattern: "**/*.test.ts"
  style: co-located  # or: separate

structure:
  organization: describe-it
  example: |
    describe('ModuleName', () => {
      describe('methodName', () => {
        it('should behavior when condition', () => {
          // arrange, act, assert
        });
      });
    });

assertions:
  library: vitest
  style: expect
  example: "expect(result).toBe(expected)"

mocks:
  library: vitest
  pattern: vi.fn()
  example: |
    const mockDep = { method: vi.fn() };
    mockDep.method.mockResolvedValue(data);

fixtures:
  setup: beforeEach
  teardown: afterEach
  data_location: null  # or: __fixtures__/, tests/fixtures/

commands:
  all: "task test"
  unit: "task test"
  watch: "task test -- --watch"
  single: "task test -- {file}"
```

### Save Location

Config path depends on how the plugin was installed:

| Plugin Scope | Config File | Git |
|--------------|-------------|-----|
| **project** | `.claude/skills/tdd.yaml` | Committed (shared) |
| **local** | `.claude/skills/tdd.local.yaml` | Ignored (personal) |
| **user** | `.claude/skills/tdd.local.yaml` | Ignored (personal) |

**Precedence when reading** (first found wins):
1. `.claude/skills/tdd.local.yaml`
2. `.claude/skills/tdd.yaml`
3. Skill defaults

---

## /tdd learn <path>

**When**: New module added, want to capture its patterns

**What it does**:
1. Analyzes test files in specified path
2. Compares to existing config
3. Proposes updates if new patterns found
4. Updates `.claude/skills/tdd.yaml`

### Example

```bash
/tdd learn src/new-service/
```

```
Analyzing tests in src/new-service/...

Found 3 test files:
  - src/new-service/handler.test.ts
  - src/new-service/service.test.ts
  - src/new-service/utils.test.ts

New patterns detected:
  - Mock pattern: vi.spyOn() (not in current config)
  - Fixture: uses beforeAll for expensive setup

Propose adding to config:
  mocks.additional_patterns:
    - vi.spyOn(object, 'method')
  fixtures.expensive_setup: beforeAll

[Approve / Modify / Skip]
```

---

## /tdd (Normal Usage)

**When**: Writing tests during development

**Requires**: `.claude/skills/tdd.yaml` exists (run `/tdd configure` first)

### TDD Cycle

```
┌─────────────────────────────────────────────────────────────┐
│                      TDD CYCLE                               │
├─────────────────────────────────────────────────────────────┤
│  1. RED     →  Write failing test (using saved patterns)    │
│  2. GREEN   →  Write minimal code to pass                   │
│  3. REFACTOR → Clean up with tests green                    │
└─────────────────────────────────────────────────────────────┘
```

### Procedure

1. **Read saved config** from `.claude/skills/tdd.yaml`
2. **Define expected behavior** (Flow Spec)
3. **Write test first** using project's patterns (must fail - RED)
4. **Write minimal code** to pass (GREEN)
5. **Refactor** with tests green
6. **Verify**: `task test`

### Flow Spec Template

```markdown
## Flow Spec: {feature_name}

- **Name**: {descriptive name}
- **Entry point(s)**: (Function, method, endpoint)
- **Inputs**: (Parameters, dependencies)
- **Expected outputs**: (Return values, side effects)
- **Invariants**: (What must always be true)
- **Edge cases**: (Boundaries, error conditions)
```

---

## Non-Negotiables

1. **Tests first**: Tests must fail before code exists
2. **Fix code, not tests**: If a test fails, fix the implementation
3. **No behavior without tests**: Every new function needs a test
4. **Match project patterns**: Use patterns from saved config

## Definition of Done

- [ ] `.claude/skills/tdd.yaml` exists (discovery completed)
- [ ] Tests written first (failed before implementation)
- [ ] Tests match project patterns from config
- [ ] `task test` passes (all tests green)
- [ ] `task precommit` passes

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Write code first, tests later | Write failing test first |
| Modify test to pass | Fix the implementation |
| Invent new test patterns | Use patterns from saved config |
| Re-configure every time | Read saved `.claude/skills/tdd.yaml` |
| Skip discovery | Run `/tdd configure` during setup |

## Config Schema

```yaml
# .claude/skills/tdd.yaml
version: 1
discovered_at: "2024-01-26T12:00:00Z"

framework: vitest | jest | pytest | go | cargo
language: typescript | python | go | rust

test_locations:
  pattern: "**/*.test.ts"
  style: co-located | separate
  directories: []  # if separate style

structure:
  organization: describe-it | class-based | function-based
  naming: "should {behavior} when {condition}"
  example: |
    # actual example from project

assertions:
  library: vitest | jest | pytest | testify
  style: expect | assert
  example: "expect(x).toBe(y)"

mocks:
  library: vitest | jest | unittest.mock | gomock
  pattern: "vi.fn()"
  example: |
    # actual example from project

fixtures:
  setup: beforeEach | setUp | func setup
  teardown: afterEach | tearDown | func teardown
  data_location: null | path

commands:
  all: "task test"
  unit: "task test"
  watch: "task test -- --watch"
  single: "task test -- {file}"
```