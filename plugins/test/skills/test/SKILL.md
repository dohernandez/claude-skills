---
name: test
description: "Smart test runner with watch mode, coverage, and path-specific testing. Use when running tests or checking test coverage."
user-invocable: true
allowed-tools: [Read, Bash, Grep, Glob]
---

# Test

## Purpose

Smart test execution with multiple modes. Wraps the project's test command with intelligence: watch mode, coverage reporting, and focused testing.

## Quick Reference

| Command | Purpose |
|---------|---------|
| `/test configure` | Discover test framework and patterns |
| `/test` | Run all tests |
| `/test --watch` | Watch mode |
| `/test --coverage` | Run with coverage report |
| `/test <path>` | Run tests for specific path |

## Commands

### /test configure

**When**: Framework setup (one-time)

Discovers:
- Test framework (jest, vitest, pytest, go test, cargo test)
- Test file patterns (`*.test.ts`, `*_test.py`, etc.)
- Test commands from Taskfile/package.json/Makefile
- Coverage tools if available

**Saves to**: `.claude/skills-config.env` (framework-level test commands)

The configure wizard discovers the test framework and proposes commands:

```bash
# Example discovered configuration
TEST_COMMAND=npm test
TEST_WATCH_COMMAND=npm test -- --watch
TEST_COVERAGE_COMMAND=npm test -- --coverage
```

These enable the Taskfile tasks:
- `task test` - Run all tests
- `task test:watch` - Watch mode
- `task test:coverage` - Coverage report

---

### /test (Run All)

**When**: Run complete test suite

```bash
/test
```

**Behavior**:
1. Reads config from `.claude/skills/test.yaml`
2. Falls back to `task -t .claude/Taskfile.yaml test` if no config
3. Runs all tests
4. Reports summary

---

### /test --watch

**When**: Continuous test running during development

```bash
/test --watch
```

**Behavior**:
1. Start test runner in watch mode
2. Re-runs tests when files change

**Framework support**:
| Framework | Command |
|-----------|---------|
| vitest | `vitest --watch` |
| jest | `jest --watch` |
| pytest | `pytest-watch` or `ptw` |
| go test | External: `watchexec -e go -- go test ./...` |

---

### /test <path>

**When**: Run tests for specific file or directory

```bash
/test src/auth/
/test src/user.test.ts
/test tests/integration/
```

**Behavior**:
1. If path is a test file: run it directly
2. If path is a source file: find corresponding test file
3. If path is a directory: run all tests in that directory

---

### /test --coverage

**When**: Run tests with coverage report

```bash
/test --coverage
```

**Behavior**:
1. Run tests with coverage flag
2. Display coverage summary
3. Report path to full coverage report

---

## Configuration

### Config Location

Config path depends on how the plugin was installed:

| Plugin Scope | Config File | Git |
|--------------|-------------|-----|
| **project** | `.claude/skills/test.yaml` | Committed (shared) |
| **local** | `.claude/skills/test.local.yaml` | Ignored (personal) |
| **user** | `.claude/skills/test.local.yaml` | Ignored (personal) |

**Precedence when reading** (first found wins):
1. `.claude/skills/test.local.yaml`
2. `.claude/skills/test.yaml`
3. Skill defaults

### Config Schema

```yaml
version: 1
discovered_at: "ISO timestamp"

framework: vitest | jest | pytest | go | cargo
language: typescript | javascript | python | go | rust

patterns:
  test_files: "glob pattern"
  test_directories: []
  source_to_test_mapping:
    - source: "src/**/*.ts"
      test: "src/**/*.test.ts"

commands:
  all: "command to run all tests"
  watch: "command for watch mode"
  single: "command with {file} placeholder"
  coverage: "command for coverage"

coverage:
  tool: "v8 | istanbul | coverage.py | go cover"
  report_path: "coverage/"
  threshold: 80

options:
  parallel: true
  bail: false
  verbose: false
```

---

## Examples

### Run tests with coverage

```bash
/test --coverage
```

Output:
```
Running tests with coverage...

 PASS  src/auth/login.test.ts (3 tests)
 PASS  src/api/handler.test.ts (5 tests)
 PASS  src/utils/helpers.test.ts (8 tests)

Coverage Summary:
  Statements: 87.5% (140/160)
  Branches:   82.3% (45/55)
  Functions:  91.2% (52/57)
  Lines:      88.1% (138/157)

Full report: coverage/index.html
```

### Debug a specific test file

```bash
/test src/auth/login.test.ts
```

---

## Integration with Other Skills

| Skill | Integration |
|-------|-------------|
| `/tdd` | Uses `/test` for running tests in TDD cycle |
| `/developer` | Calls `/test` before completing |
| `/bugfix` | Uses `/test` to verify fix |
| `/workflow` | Runs `/test` before PR |

---

## Troubleshooting

### "TEST_COMMAND not configured"

Run `/test configure` or `/framework configure` to set up test commands.

### Watch mode not working

Some frameworks need additional packages:
- pytest: `pip install pytest-watch`
- go: `brew install watchexec`
