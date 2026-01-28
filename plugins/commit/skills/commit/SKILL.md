---
name: commit
description: "Create git commits with conventional commit messages. Use when user says /commit."
user-invocable: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Commit

## Purpose

Create standardized git commits following Conventional Commits specification. Analyzes changes to determine appropriate type, scope, and message.

## Quick Reference

- **Setup**: `/commit configure` (run once per project)
- **Usage**: `/commit` (uses saved scopes)
- **Update**: `/commit learn` (re-analyze scopes from recent commits)
- **Config**: Depends on installation model (see Save Location)

## Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/commit configure` | Analyze project for commit scopes | First time in a project |
| `/commit learn` | Update scopes from recent commits | After project changes |
| `/commit` | Create commit using saved scopes | Normal usage |

---

## /commit configure

**When**: First time using `/commit` in a project

**What it does**:
1. Scans project structure for scope candidates
2. Analyzes recent commit history for patterns
3. Proposes scope configuration to user
4. Saves config based on plugin installation scope

### Discovery Process

```
1. SCAN PROJECT STRUCTURE
   ├─ Top-level src/ directories
   ├─ Workspace packages (package.json workspaces)
   ├─ Go modules (go.work)
   └─ Python packages (pyproject.toml)

2. ANALYZE COMMIT HISTORY
   ├─ Extract scopes from last 100 commits
   ├─ Count frequency of each scope
   └─ Identify naming patterns

3. PROPOSE TO USER
   └─ Show discovered scopes, wait for approval
```

### Proposal Format

```yaml
# Proposed Commit Configuration
# Review and approve to save to .claude/skills/commit.yaml

scopes:
  - name: api
    description: "REST API endpoints"
    paths: ["src/api/", "api/"]
  - name: auth
    description: "Authentication and authorization"
    paths: ["src/auth/", "src/middleware/auth"]
  - name: db
    description: "Database and migrations"
    paths: ["src/db/", "migrations/"]
  - name: ui
    description: "User interface components"
    paths: ["src/components/", "src/pages/"]
  - name: core
    description: "Core business logic"
    paths: ["src/core/", "src/domain/"]
  - name: infra
    description: "Infrastructure and deployment"
    paths: ["infra/", "terraform/", "k8s/"]
  - name: deps
    description: "Dependencies"
    paths: ["package.json", "go.mod", "Cargo.toml"]
  - name: ci
    description: "CI/CD configuration"
    paths: [".github/", ".gitlab-ci.yml"]

types:
  changelog_worthy: [feat, fix, perf]
  internal: [chore, ci, test, docs, style, refactor, build]

rules:
  max_title_length: 50
  require_scope: false
  require_body: false
  forbidden_words: ["stuff", "things", "misc", "update", "improve"]
```

### Save Location

Config path depends on the installation model. Detect which model is active by checking whether this skill is running from inside `.claude/skills/commit/` (copied) or from an external plugin directory.

| Installation Model | Config File | How to Detect |
|--------------------|-------------|---------------|
| **Claude Code plugin** (external) | `.claude/skills/commit.yaml` | Skill files are NOT inside `.claude/skills/commit/` |
| **Copied into project** | `.claude/skills/commit/commit.yaml` | Skill files ARE inside `.claude/skills/commit/` |

**Precedence when reading** (first found wins):
1. `.claude/skills/commit/commit.yaml` (copied installation)
2. `.claude/skills/commit.yaml` (plugin installation)
3. Skill defaults

---

## /commit learn

**When**: Project structure changed, want to update scopes

**What it does**:
1. Re-analyzes project structure
2. Scans recent commits for new scopes
3. Proposes updates to config
4. Updates existing config file (respects installation model)

---

## /commit (Normal Usage)

**When**: Creating a commit

**Reads config from** (first found):
1. `.claude/skills/commit/commit.yaml` (copied installation)
2. `.claude/skills/commit.yaml` (plugin installation)
3. Skill defaults

### Workflow

```
1. PRE-COMMIT CHECKS (before any commit)
   ├─ Check not on main/master branch
   ├─ Check no secrets in staged files (.env, credentials, .pem, .key)
   └─ STOP if any check fails

2. ANALYZE CHANGES
   ├─ git status --porcelain
   ├─ git diff --staged
   └─ git diff (unstaged)

3. DETERMINE SCOPE
   └─ Match changed files to scopes from config

4. GENERATE MESSAGE
   ├─ Type: from change analysis
   ├─ Scope: from config mapping
   └─ Subject: from change description

5. USER CONFIRMATION
   └─ Show message, wait for approval

6. EXECUTE COMMIT
   └─ git commit with approved message
```

---

## Conventional Commit Format

```
<type>(<scope>): <subject>

<optional body - 1-2 sentences>
```

## Commit Types

| Type | Purpose | Changelog |
|------|---------|-----------|
| `feat` | New feature | Yes |
| `fix` | Bug fix | Yes |
| `docs` | Documentation only | No |
| `style` | Formatting (no logic) | No |
| `refactor` | Code refactor | No |
| `perf` | Performance improvement | Yes |
| `test` | Add/update tests | No |
| `build` | Build system/deps | No |
| `ci` | CI/config changes | No |
| `chore` | Maintenance | No |
| `revert` | Revert commit | Yes |

## Rules

- [ ] Title ≤ 50 characters
- [ ] Title is SPECIFIC (no vague words)
- [ ] Imperative mood ("add" not "added")
- [ ] Body: 1-2 sentences max, or omit
- [ ] Focus on WORK done, not file operations
- [ ] Never commit secrets
- [ ] **NO AI attribution**
- [ ] **NO ticket references** (put in PR instead)

## AI Attribution Policy

**STRICTLY FORBIDDEN** - Never include:
- `Co-Authored-By: Claude` or any AI name
- 🤖 emoji or AI-related emojis
- "Generated by", "Created with"
- Any reference to AI tools

## Git Safety

- **NEVER** commit directly to main/master
- **NEVER** run destructive commands
- **NEVER** skip hooks unless user asks
- If hook fails: fix issue, create NEW commit (don't amend)

## Examples

**Good:**
```
feat(auth): add OAuth2 login support

Adds Google and GitHub OAuth providers.
```

```
fix(api): handle null response from external service
```

```
refactor(db): extract query builder to separate module
```

**Bad:**
- `chore: update stuff` (vague)
- `feat(api): improved performance` (past tense)
- `docs: add file to docs folder` (file-focused)

## Config Schema

```yaml
# .claude/skills/commit.yaml (plugin installation)
# .claude/skills/commit/commit.yaml (copied installation)
version: 1
discovered_at: "ISO timestamp"

scopes:
  - name: "scope-name"
    description: "what it covers"
    paths: ["paths/", "that/match/"]

types:
  changelog_worthy: [feat, fix, perf]
  internal: [chore, ci, test, docs, style, refactor, build]

rules:
  max_title_length: 50
  require_scope: false
  require_body: false
  forbidden_words: []
```
