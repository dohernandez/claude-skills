---
name: tdd
description: "Enforce TDD discipline: tests first, fix code not tests. Use when user says /tdd or /test."
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
hooks:
  Stop:
    - type: command
      command: "task claude:validate-skill -- --skill tdd"
---

# TDD

## Purpose

Enforce Test-Driven Development discipline. All changes must have tests written first, tests must fail before implementation, and when tests fail, fix the code not the tests.

## Quick Reference

- **Core rule**: Tests first, code second
- **When tests fail**: Fix the implementation, not the test
- **Gate**: Tests must pass before work is considered done
- **First step**: Discover project's testing patterns before writing tests

## TDD Cycle

```
┌─────────────────────────────────────────────────────────────┐
│                      TDD CYCLE                               │
├─────────────────────────────────────────────────────────────┤
│  1. RED     →  Write failing test                           │
│  2. GREEN   →  Write minimal code to pass                   │
│  3. REFACTOR → Clean up with tests green                    │
└─────────────────────────────────────────────────────────────┘
```

## Procedure

1. **Discover project testing patterns** (first time only)
2. **Define expected behavior** (Flow Spec)
3. **Write test first** (must fail - RED)
4. **Write minimal code** to pass (GREEN)
5. **Refactor** with tests green
6. **Repeat** for next behavior

## Discover Project Testing Patterns

Before writing tests, learn how this project does testing:

### 1. Find Test Framework

```bash
# Check package.json for JS/TS projects
grep -E "jest|vitest|mocha|ava" package.json

# Check for pytest/unittest in Python
grep -E "pytest|unittest" requirements.txt setup.py pyproject.toml 2>/dev/null

# Check for Go test files
find . -name "*_test.go" -type f | head -5
```

### 2. Find Existing Test Examples

```bash
# Find test files
find . -name "*.test.*" -o -name "*_test.*" -o -name "test_*" | head -10

# Look at test organization
ls -la tests/ test/ __tests__/ 2>/dev/null
```

### 3. Learn Project Patterns

Read 2-3 existing test files to understand:
- **File naming**: `*.test.ts`, `*_test.go`, `test_*.py`
- **Test structure**: describe/it, class-based, function-based
- **Mock patterns**: How dependencies are mocked
- **Fixture patterns**: How test data is organized
- **Assertion style**: expect, assert, require

### 4. Check Test Commands

```bash
# Check Taskfile for test commands
grep -A2 "test:" Taskfile.yaml 2>/dev/null

# Check package.json scripts
grep -A5 '"scripts"' package.json 2>/dev/null | grep test

# Check Makefile
grep "test:" Makefile 2>/dev/null
```

**Key rule**: Match the project's existing test patterns. Don't introduce new testing styles.

## Flow Spec Template

Before writing code, document what you're building:

```markdown
## Flow Spec: {feature_name}

- **Name**: {descriptive name}
- **Entry point(s)**: (Function, method, endpoint)
- **Inputs**: (Parameters, dependencies)
- **Expected outputs**: (Return values, side effects)
- **Invariants**: (What must always be true)
- **Edge cases**: (Boundaries, error conditions)
```

## Test Requirements

### Unit Tests
- Test pure functions and business logic
- Use mocks for external dependencies
- One assertion per test (when practical)
- Descriptive test names

### Integration Tests
- Test component interactions
- Verify end-to-end flows
- Use realistic test data

## Non-Negotiables

1. **Tests first**: Tests must fail before code exists
2. **Fix code, not tests**: If a test fails, fix the implementation
3. **No behavior without tests**: Every new function needs a test
4. **Tests define correctness**: The test is the specification

## Commands

```bash
# Run all tests
task test

# Run tests in watch mode (if supported)
task test -- --watch

# Run specific test file
task test -- path/to/file.test.ts

# Run precommit (lint + tests)
task precommit
```

## Test File Organization

Tests should be co-located with source files:

```
src/
  services/
    user-service.ts
    user-service.test.ts
  utils/
    validate.ts
    validate.test.ts
```

Or in a parallel test directory:

```
src/
  services/
    user-service.ts
tests/
  services/
    user-service.test.ts
```

## Writing Good Tests

### Describe/It Structure

```
# TypeScript/JavaScript (Jest/Vitest)
describe('UserService', () => {
  describe('createUser', () => {
    it('creates user with valid data', () => { ... });
    it('throws error for invalid email', () => { ... });
  });
});

# Python (pytest)
class TestUserService:
    def test_create_user_with_valid_data(self): ...
    def test_create_user_throws_for_invalid_email(self): ...

# Go
func TestUserService_CreateUser(t *testing.T) { ... }
func TestUserService_CreateUser_InvalidEmail(t *testing.T) { ... }
```

### Test Naming

- Describe **what** is being tested
- Describe **expected behavior**
- Include **conditions** if relevant

Good: `it('returns empty array when no users exist')`
Bad: `it('test1')`

## Definition of Done

- [ ] Flow Spec written for the feature
- [ ] Tests written first (failed before implementation)
- [ ] `task test` passes (all tests green)
- [ ] No skipped tests unless documented
- [ ] `task precommit` passes

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Write code first, tests later | Write failing test first |
| Modify test to pass | Fix the implementation |
| Skip tests "temporarily" | Write the test or don't commit |
| Test implementation details | Test public behavior |
| Share mutable state between tests | Isolate each test |

## Automation

- `skill.yaml` - patterns and procedures
- `sharp-edges.yaml` - common TDD failure modes
- `validations.yaml` - test validation on stop