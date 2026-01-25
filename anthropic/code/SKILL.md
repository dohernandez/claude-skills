# Code Skill

Code style discovery, validation, and guidance for writing defensive, well-reasoned code.

## Modes Overview

| Mode | Command | Purpose |
|------|---------|---------|
| **discover** | `/code discover` | Read style from linter/formatter configs |
| **learn** | `/code learn` | Infer style from actual code patterns |
| **check** | `/code check` | Validate code follows style |
| **guide** | `/code guide` | Mindset primer + style guidance |

---

### Discover Mode: `/code discover` (Setup)

Discovers code style from existing linter/formatter configurations.

```bash
/code discover
```

**What it checks by language:**

| Language | Tools Discovered |
|----------|------------------|
| TypeScript | eslint, prettier, biome, tsconfig |
| Python | ruff, black, flake8, isort, mypy |
| Go | golangci-lint, gofmt, goimports |
| Rust | clippy, rustfmt |
| Java | checkstyle, pmd, google-java-format |
| Generic | .editorconfig |

**Output:**
```
## Discovered Code Style

**Language:** TypeScript
**Confidence:** High (eslint + prettier found)

### Tools Found
| Tool | Config | Status |
|------|--------|--------|
| eslint | .eslintrc.json | Found |
| prettier | .prettierrc | Found |
| typescript | tsconfig.json | Found |

### Style Rules
| Category | Rule | Source |
|----------|------|--------|
| Indent | 2 spaces | .prettierrc |
| Quotes | single | .prettierrc |
| Semicolons | yes | .prettierrc |
| Naming | camelCase | default |

**Save this configuration?** [Confirm / Adjust]
```

---

### Learn Mode: `/code learn`

Infers code style from actual code patterns.

```bash
# Analyze codebase (default)
/code learn --analyze

# Learn from exemplar file
/code learn --from src/services/user-service.ts
```

**What it analyzes:**
1. **Naming patterns** - Functions, variables, classes, constants
2. **Import patterns** - Grouping, ordering, type imports
3. **Formatting** - Indent, quotes, semicolons, line length

**Output:**
```
## Inferred Code Style

**Method:** Code analysis (47 files)
**Confidence:** Medium

### Naming Conventions (inferred)
| Pattern | Examples | Confidence |
|---------|----------|------------|
| Functions: camelCase | getData, parseUser | 95% (142/150) |
| Classes: PascalCase | UserService, DataLoader | 100% (23/23) |
| Constants: UPPER_SNAKE | MAX_RETRIES, API_URL | 87% (13/15) |

### Formatting (inferred)
| Rule | Detected | Confidence |
|------|----------|------------|
| Indent | 2 spaces | 100% |
| Quotes | single | 78% |
| Semicolons | yes | 100% |

**Save this configuration?** [Confirm / Adjust]
```

---

### Check Mode: `/code check`

Validates code follows configured style.

```bash
/code check           # Check all files
/code check src/      # Check specific directory
/code check file.ts   # Check specific file
```

**What it runs by language:**

| Language | Commands |
|----------|----------|
| TypeScript | `npx eslint .` + `npx prettier --check .` |
| Python | `ruff check .` + `black --check .` |
| Go | `golangci-lint run` + `gofmt -d .` |
| Rust | `cargo clippy` + `cargo fmt --check` |

**Output:**
```
## Code Style Check

**Status:** FAIL (7 violations)

### Violations
| File | Line | Rule | Message |
|------|------|------|---------|
| src/user.ts | 15 | naming-convention | Variable 'UserData' should be camelCase |
| src/api.ts | 42 | prettier | Replace double quotes with single quotes |

### Summary
- Errors: 2
- Warnings: 5

Run `npx eslint . --fix` to auto-fix 5 violations.
```

---

### Guide Mode: `/code guide`

Mindset primer + style guidance when writing code.

```bash
/code guide                    # General guidance
/code guide "new service"      # Context-specific guidance
```

**Output:**
```
## Code Mindset

You are entering a code field.

Before you write:
- What are you assuming about the input?
- What are you assuming about the environment?
- What would break this?
- What would a malicious caller do?
- What would a tired maintainer misunderstand?

Do not:
- Write code before stating assumptions
- Handle the happy path and gesture at the rest
- Produce code you wouldn't want to debug at 3am

The question is not "Does this work?" but
"Under what conditions does this work?"

---

### Style for TypeScript Functions

**Naming:**
- Use camelCase: `getUserData`, `parseResponse`
- Prefix with verb: `get*`, `fetch*`, `parse*`, `build*`

**Parameters:**
- Context first if needed: `(ctx: Context, ...)`
- Options object for 3+ params

**Example:**
```typescript
async function fetchUserData(
  ctx: Context,
  userId: string
): Promise<UserResult> {
  if (!userId) {
    return { success: false, error: "userId required" };
  }

  const data = await api.getUser(ctx, userId);

  return { success: true, data };
}
```
```

---

## Style Templates by Language

### TypeScript
| Category | Convention |
|----------|------------|
| Files | kebab-case (`user-service.ts`) |
| Functions | camelCase (`getUserData`) |
| Variables | camelCase (`userId`) |
| Constants | UPPER_SNAKE_CASE (`MAX_RETRIES`) |
| Types/Interfaces | PascalCase (`UserData`) |
| Private | _camelCase (`_cache`) |

### Python
| Category | Convention |
|----------|------------|
| Files | snake_case (`user_service.py`) |
| Functions | snake_case (`get_user_data`) |
| Variables | snake_case (`user_id`) |
| Constants | UPPER_SNAKE_CASE (`MAX_RETRIES`) |
| Classes | PascalCase (`UserService`) |
| Private | _snake_case (`_cache`) |

### Go
| Category | Convention |
|----------|------------|
| Files | snake_case (`user_service.go`) |
| Functions | camelCase/PascalCase (`getUserData`/`GetUserData`) |
| Variables | camelCase (`userID`) |
| Types | PascalCase (`UserData`) |
| Unexported | lowercase (`internal`) |

### Rust
| Category | Convention |
|----------|------------|
| Files | snake_case (`user_service.rs`) |
| Functions | snake_case (`get_user_data`) |
| Variables | snake_case (`user_id`) |
| Constants | UPPER_SNAKE_CASE (`MAX_RETRIES`) |
| Types/Traits | PascalCase (`UserData`) |

---

## Mindset Patterns

### Do
- **Assumptions first** - State assumptions before writing code
- **Edge cases before happy path** - Enumerate failure modes first
- **Smaller than instinct** - First implementation is usually too large
- **Defend what you write** - If you can't explain it, don't write it

### Don't
- **Completion reflex** - Rushing to produce running code
- **Pattern matching** - Copying similar code without understanding differences
- **Happy path only** - Error handling "later" means never
- **Premature abstraction** - Creating abstractions before the second use case

---

## Integration

The `code` skill integrates with:
- **arch** - Get layer context for applicable patterns
- **developer** - Get style guidance during implementation
- **commit** - Run check before committing
