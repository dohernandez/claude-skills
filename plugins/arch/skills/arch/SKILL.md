---
name: arch
description: Architecture discovery, validation, and planning. Use when user says /arch, /arch configure, /arch learn, /arch check, or /arch plan.
user-invocable: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Architecture Skill

## Purpose

Discover, validate, and guide project architecture. Ensures code follows layer boundaries and helps plan where new code should go.

## Quick Reference

- **Validates:** Layer boundaries, import directions, architectural compliance
- **Modes:** configure, learn, check, plan

## Modes Overview

| Mode | Command | Purpose |
|------|---------|---------|
| **configure** | `/arch configure` | Auto-discover from docs/configs (setup) |
| **learn** | `/arch learn` | Infer from code analysis or description |
| **check** | `/arch check` | Validate layer boundaries |
| **plan** | `/arch plan <desc>` | Suggest where new code belongs |

---

### Configure Mode: `/arch configure` (Setup)

Auto-discovers your project's architecture based on the selected style.

**Run during plugin installation or manually:**
```bash
/arch configure
```

**Discovery Flow:**

1. **User selects architecture style:**
   - hexagonal, layered, clean, mvc, custom

2. **Skill searches for architecture documentation:**
   - CLAUDE.md (Architecture section)
   - README.md (Project Structure section)
   - docs/architecture.md
   - docs/ADR/*.md (Architecture Decision Records)

3. **Skill checks config files:**
   - tsconfig.json (path aliases → layers)
   - .eslintrc (import restriction rules)
   - .dependency-cruiser.js
   - package.json (workspaces)

4. **Skill scans directory structure:**
   - src/, lib/, app/, packages/
   - Matches directories to style template

5. **Presents discovered config for confirmation:**

```
## Discovered Architecture

**Style:** hexagonal
**Source Root:** src/
**Confidence:** High (documented in CLAUDE.md)

### Layers (lowest → highest)

| Level | Name | Path | Responsibility |
|-------|------|------|----------------|
| 0 | config | src/config/ | Configuration, schemas |
| 1 | domain | src/domain/ | Core business logic |
| 2 | infrastructure | src/infrastructure/ | External integrations |
| 3 | application | src/application/ | Use cases, orchestration |

### Sources Used
- CLAUDE.md (Architecture section)
- tsconfig.json (path aliases)
- Directory scan (src/)

**Is this correct?** [Confirm / Adjust]
```

### Learn Mode: `/arch learn`

Learn architecture from code analysis or a provided description.

**Options:**

```bash
# Analyze actual import patterns (default)
/arch learn --analyze

# Parse a natural language description
/arch learn --from "We use hexagonal architecture with domain at center..."

# Learn from labeled examples
/arch learn --example "src/domain/user.py=domain" --example "src/api/routes.py=application"
```

**What `--analyze` does:**

1. **Builds import graph** - Scans all source files, extracts imports
2. **Identifies clusters** - Groups by directory, calculates import metrics
3. **Infers layer levels** - Uses heuristics based on import direction
4. **Detects violations** - Finds cycles and backward imports
5. **Compares to docs** - Generates drift report if architecture already configured

**Output:**
```
## Inferred Architecture

**Method:** Import analysis
**Confidence:** Medium (no docs, inferred from code)

### Detected Layers

| Level | Directory | Inbound | Outbound | Role |
|-------|-----------|---------|----------|------|
| 0 | src/domain/ | 47 | 3 | Core (most depended on) |
| 1 | src/infrastructure/ | 23 | 15 | Middle (adapters) |
| 2 | src/application/ | 5 | 38 | Orchestrator |

### Import Graph Summary
```
domain ← infrastructure ← application
       ↖________________↙
```

### Cycles Detected: 2
1. src/infra/cache.py ↔ src/infra/db.py
2. src/app/service.py → src/domain/user.py → src/app/utils.py

**Save this configuration?** [Confirm / Adjust]
```

**Layer inference heuristics:**
- **Lower layers (L0, L1):** High inbound imports, low outbound (many depend on them)
- **Higher layers (L2, L3):** Low inbound imports, high outbound (orchestrators)
- **Formula:** `layer_level ∝ outbound_imports / inbound_imports`

---

### Check Mode: `/arch check`

Validate that code follows architecture layer boundaries.

```bash
/arch check
```

**What it checks:**
- Import violations (inner layers importing outer)
- Circular dependencies
- Layer bypass (skipping intermediate layers)

**Output:**
```
## Architecture Check

Status: FAIL

### Violations Found (2)

1. src/domain/user.ts:5
   Import: from '../infrastructure/database'
   Rule: Domain cannot import Infrastructure
   Fix: Use dependency injection or move to Application layer

2. src/business/order.ts:12
   Import: from '../presentation/api'
   Rule: Business cannot import Presentation
   Fix: Invert dependency with interface
```

### Plan Mode: `/arch plan <description>`

Get guidance on where new code should go.

```bash
/arch plan Add user authentication with JWT tokens
```

**Output:**
```
## Architecture Plan: User Authentication

Based on your hexagonal architecture:

### Layer Distribution

| Layer | What Goes Here | Files |
|-------|----------------|-------|
| Domain | User entity, AuthToken value object | src/domain/user/, src/domain/auth/ |
| Infrastructure | JWTProvider adapter | src/infrastructure/jwt/ |
| Application | AuthenticationService use case | src/application/auth/ |

### Reasoning

- **Domain**: User identity and tokens are core business concepts
- **Infrastructure**: JWT is an external technology detail
- **Application**: Authentication orchestrates domain + infra

### Implementation Order

1. Domain first (no dependencies)
2. Infrastructure (depends on domain types)
3. Application (orchestrates both)
```

## Discovery Sources

The skill configures architecture from these sources (in priority order):

### Documentation Files

| File | What's Extracted |
|------|------------------|
| `CLAUDE.md` | Architecture section, layer descriptions |
| `README.md` | Project Structure section |
| `docs/architecture.md` | Full architecture documentation |
| `docs/ADR/*.md` | Architecture Decision Records |

### Config Files (Language-Specific)

The skill auto-detects project language and checks relevant configs:

**TypeScript/JavaScript:**
| File | What's Extracted |
|------|------------------|
| `tsconfig.json` | Path aliases (often mirror layers) |
| `.eslintrc*` | `import/no-restricted-paths` rules |
| `.dependency-cruiser.js` | Forbidden dependency rules |
| `package.json` | Workspaces (monorepo structure) |

**Python:**
| File | What's Extracted |
|------|------------------|
| `pyproject.toml` | Package structure, import-linter config |
| `.importlinter` | Layer contracts and forbidden imports |
| `setup.cfg` | packages and package_dir |
| `mypy.ini` | Per-module type settings |

**Go:**
| File | What's Extracted |
|------|------------------|
| `go.mod` | Module name reveals structure |
| `go.work` | Workspace members (monorepo) |
| `.golangci.yml` | depguard rules for import restrictions |
| `internal/` | Go convention for private packages |

**Rust:**
| File | What's Extracted |
|------|------------------|
| `Cargo.toml` | Workspace members |
| `.cargo/config.toml` | Alias paths |

**Java/Kotlin:**
| File | What's Extracted |
|------|------------------|
| `build.gradle` | Subprojects/modules |
| `pom.xml` | Multi-module structure |
| `archunit.properties` | ArchUnit layer rules |

**Generic (all languages):**
| File | What's Extracted |
|------|------------------|
| `Makefile` | Targets often mirror layers |
| `docker-compose.yml` | Services may represent boundaries |
| `justfile` | Recipes may mirror structure |

### Directory Scan (Fallback)

If documentation doesn't fully define layers:
- Scans common source roots: `src/`, `lib/`, `app/`, `packages/`
- Go projects: also scans `pkg/`, `internal/`, `cmd/`
- Matches directories against style template
- Assigns default responsibilities based on naming conventions

## Architecture Styles

| Style | Description | Typical Layers |
|-------|-------------|----------------|
| **hexagonal** | Ports & Adapters | config → domain → infrastructure → application |
| **layered** | Traditional layers | data → business → presentation |
| **clean** | Clean Architecture | entities → usecases → adapters → frameworks |
| **mvc** | Model-View-Controller | models → controllers/views |
| **custom** | User-defined | User configures |

## Confidence Levels

| Level | Meaning | Sources |
|-------|---------|---------|
| **High** | Architecture explicitly documented | CLAUDE.md, README.md, docs/architecture.md |
| **Medium** | Inferred from config | tsconfig.json paths, eslint rules |
| **Low** | Only directory structure | Fallback scan of src/ |

## Integration with Developer Skill

The `developer` skill uses `/arch plan` before implementation:

```
1. User: "Add user authentication"
2. Developer calls: /arch plan Add user authentication
3. Arch returns: layer assignments + reasoning
4. Developer routes to appropriate patterns
```

## Anti-Patterns Detected

| Pattern | Problem | Fix |
|---------|---------|-----|
| Domain imports Infrastructure | Violates dependency inversion | Use DI or move code |
| Circular imports | Runtime issues, tight coupling | Extract to lower layer |
| Layer bypass | Hidden dependencies | Route through proper layers |
| God module | Too many responsibilities | Split into focused modules |

## Configuration

### Config Location

Config path depends on how the plugin was installed:

| Plugin Scope | Config File | Git |
|--------------|-------------|-----|
| **project** | `.claude/skills/arch.yaml` | Committed (shared) |
| **local** | `.claude/skills/arch.local.yaml` | Ignored (personal) |
| **user** | `.claude/skills/arch.local.yaml` | Ignored (personal) |

**Precedence when reading** (first found wins):
1. `.claude/skills/arch.local.yaml`
2. `.claude/skills/arch.yaml`
3. Skill defaults

### Config Schema

After discovery, saved to the config file:

```yaml
ARCHITECTURE_STYLE: hexagonal
SOURCE_ROOT: src/
LAYERS:
  - name: config
    level: 0
    path: src/config/
    responsibility: Configuration, schemas
    can_import: [external]
  - name: domain
    level: 1
    path: src/domain/
    responsibility: Core business logic
    can_import: [config, external]
  - name: infrastructure
    level: 2
    path: src/infrastructure/
    responsibility: External integrations
    can_import: [config, domain, external]
  - name: application
    level: 3
    path: src/application/
    responsibility: Use cases, orchestration
    can_import: [config, domain, infrastructure, external]
```
