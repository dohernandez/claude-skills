---
name: code
description: "Code style discovery, validation, and guidance. Use when user says /code."
user-invocable: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
hooks:
  Stop:
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill code"
---

# Code

## Purpose

Discover, validate, and guide code style. Ensures consistent code patterns across the project by learning from existing configurations and code.

## Quick Reference

- **Setup**: `/code configure` (run once during framework setup)
- **Usage**: `/code guide`, `/code check`
- **Update**: `/code learn <path>` (analyze specific path)
- **Config**: `.claude/skills/code.yaml`

## Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/code configure` | Analyze project for code style | Framework setup / wizard |
| `/code learn <path>` | Analyze specific path, update config | New module/patterns |
| `/code check [path]` | Validate code follows style | Before commit |
| `/code guide [context]` | Get style guidance | When writing code |

---

## /code configure

**When**: Framework setup wizard (one-time)

**What it does**:
1. Scans project for linter/formatter configs
2. Analyzes code patterns
3. Proposes style configuration to user
4. Saves to `.claude/skills/code.yaml`

### Discovery Process

```
1. DETECT LANGUAGE & TOOLS
   ├─ TypeScript: eslint, prettier, biome, tsconfig
   ├─ Python: ruff, black, flake8, isort, mypy, pyproject.toml
   ├─ Go: golangci-lint, gofmt, goimports
   ├─ Rust: clippy, rustfmt, Cargo.toml
   ├─ Java: checkstyle, pmd, google-java-format
   └─ Generic: .editorconfig

2. READ CONFIG FILES
   ├─ Extract rules from linter configs
   ├─ Extract formatting rules
   └─ Identify custom rules

3. ANALYZE CODE PATTERNS (sample 20-30 files)
   ├─ Naming conventions (functions, variables, classes, constants)
   ├─ Import organization (grouping, ordering)
   ├─ Formatting (indent, quotes, semicolons, line length)
   └─ Code structure patterns

4. PROPOSE TO USER
   └─ Show discovered style, wait for approval
```

### Proposal Format

```yaml
# Proposed Code Style Configuration
# Review and approve to save to .claude/skills/code.yaml

language: typescript
confidence: high

tools:
  linter: eslint
  formatter: prettier
  type_checker: typescript

formatting:
  indent: 2 spaces
  quotes: single
  semicolons: true
  line_length: 100
  trailing_comma: es5

naming:
  files: kebab-case
  functions: camelCase
  variables: camelCase
  constants: UPPER_SNAKE_CASE
  classes: PascalCase
  types: PascalCase
  private: _camelCase

imports:
  order:
    - builtin
    - external
    - internal
    - relative
  grouping: true
  type_imports: separate

patterns:
  error_handling: "Result type pattern"
  async: "async/await preferred"
  comments: "JSDoc for public APIs"

commands:
  lint: "task lint"
  format: "task format"
  check: "task precommit"

examples:
  function: |
    async function fetchUserData(
      ctx: Context,
      userId: string
    ): Promise<Result<User>> {
      // ...
    }
```

### Save Location

Config path depends on how the plugin was installed:

| Plugin Scope | Config File | Git |
|--------------|-------------|-----|
| **project** | `.claude/skills/code.yaml` | Committed (shared) |
| **local** | `.claude/skills/code.local.yaml` | Ignored (personal) |
| **user** | `.claude/skills/code.local.yaml` | Ignored (personal) |

**Precedence when reading** (first found wins):
1. `.claude/skills/code.local.yaml`
2. `.claude/skills/code.yaml`
3. Skill defaults

---

## /code learn <path>

**When**: New module added, want to capture its patterns

**What it does**:
1. Analyzes code files in specified path
2. Compares to existing config
3. Proposes updates if new patterns found
4. Updates `.claude/skills/code.yaml`

### Example

```bash
/code learn src/new-module/
```

```
Analyzing code in src/new-module/...

Found 8 source files.

Patterns detected:
  - Naming: uses `_internal` prefix for private functions
  - Imports: groups by domain (users, orders, common)
  - New pattern: uses `Result<T, E>` type for all returns

Compare to existing config:
  - private naming: _camelCase → _internal* prefix (NEW)
  - result type: not in config (NEW)

Propose adding to config:
  naming.private_prefix: "_internal"
  patterns.result_type: "Result<T, E>"

[Approve / Modify / Skip]
```

---

## /code check [path]

**When**: Validate code before commit

**Requires**: `.claude/skills/code.yaml` exists

**What it does**:
1. Reads style from saved config
2. Runs configured linter/formatter
3. Reports violations

```bash
/code check              # Check all files
/code check src/users/   # Check specific path
/code check file.ts      # Check single file
```

### Output

```
## Code Style Check

**Config:** .claude/skills/code.yaml
**Status:** FAIL (7 violations)

### Violations
| File | Line | Rule | Message |
|------|------|------|---------|
| src/user.ts | 15 | naming | Variable 'UserData' should be camelCase |
| src/api.ts | 42 | formatting | Use single quotes, not double |

### Summary
- Errors: 2
- Warnings: 5

Auto-fix available: Run `task lint --fix`
```

---

## /code guide [context]

**When**: Need style guidance while writing code

**Requires**: `.claude/skills/code.yaml` exists (or uses defaults)

```bash
/code guide                    # General mindset
/code guide "new service"      # Context-specific
/code guide "error handling"   # Topic-specific
```

### Output

```
## Code Mindset

You are entering a code field.

Before you write:
- What are you assuming about the input?
- What would break this?
- What would a malicious caller do?
- What would a tired maintainer misunderstand?

Do not:
- Write code before stating assumptions
- Handle only the happy path
- Produce code you wouldn't want to debug at 3am

---

## Style for This Project (from .claude/skills/code.yaml)

**Language:** TypeScript

**Naming:**
- Functions: camelCase (`getUserData`, `parseResponse`)
- Classes: PascalCase (`UserService`)
- Constants: UPPER_SNAKE_CASE (`MAX_RETRIES`)

**Formatting:**
- Indent: 2 spaces
- Quotes: single
- Semicolons: yes

**Example:**
```typescript
async function fetchUserData(
  ctx: Context,
  userId: string
): Promise<Result<User>> {
  if (!userId) {
    return err("userId required");
  }
  const data = await api.getUser(ctx, userId);
  return ok(data);
}
```
```

---

## Non-Negotiables

1. **Match project patterns**: Use style from saved config
2. **Run checks before commit**: `/code check` before `/commit`
3. **Don't invent new patterns**: Follow discovered conventions

## Config Schema

```yaml
# .claude/skills/code.yaml
version: 1
discovered_at: "ISO timestamp"

language: typescript | python | go | rust
confidence: high | medium | low

tools:
  linter: eslint | ruff | golangci-lint | clippy
  formatter: prettier | black | gofmt | rustfmt
  type_checker: typescript | mypy | null

formatting:
  indent: "2 spaces" | "4 spaces" | "tabs"
  quotes: single | double
  semicolons: true | false
  line_length: 100
  trailing_comma: es5 | all | none

naming:
  files: kebab-case | snake_case | camelCase
  functions: camelCase | snake_case | PascalCase
  variables: camelCase | snake_case
  constants: UPPER_SNAKE_CASE
  classes: PascalCase
  types: PascalCase
  private: _prefix | suffix_ | none

imports:
  order: [builtin, external, internal, relative]
  grouping: true | false
  type_imports: separate | inline

patterns:
  error_handling: "description"
  async: "description"
  comments: "description"

commands:
  lint: "task lint"
  format: "task format"
  check: "task precommit"

examples:
  function: |
    # actual example from project
  class: |
    # actual example from project
```

## Integration

- **tdd** - Code skill provides style, TDD skill provides test patterns
- **commit** - Run `/code check` before committing
- **developer** - Uses code patterns for implementation guidance