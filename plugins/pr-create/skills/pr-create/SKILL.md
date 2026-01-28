---
name: pr-create
description: Creates GitHub pull requests with conventional commit-style titles. Use when creating PRs, submitting changes for review, or when user says /pr, /pr-create.
user-invocable: true
allowed-tools: [Bash, Read, Grep, Glob]
---

# PR Create

## Purpose
Creates GitHub pull requests with conventional commit-style titles and structured bodies.
Follows git workflow conventions from `.claude/skills/pr-create/git-workflow.md`.

## Quick Reference
- **Setup**: `/pr-create configure` (install default PR template)
- **Usage**: `/pr-create` (create PR)
- **Template**: `.github/PULL_REQUEST_TEMPLATE.md`
- **Config**: Depends on installation model (see Save Location)
- **Requires**: GitHub CLI installed and authenticated, committed changes on a feature branch

## Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/pr-create configure` | Install default PR template | First time in a project or to reset template |
| `/pr-create` | Create PR using template | Normal usage |

---

## /pr-create configure

**When**: First time using `/pr-create` in a project, or to install/reset the PR template

**What it does**:
1. Checks if `.github/PULL_REQUEST_TEMPLATE.md` exists
2. If exists: asks user — keep existing or replace with default?
3. If user chooses default (or no template exists): copies plugin's `templates/PULL_REQUEST_TEMPLATE.md` to `.github/PULL_REQUEST_TEMPLATE.md`
4. Saves config to yaml (installation-model-aware path)

### Workflow

```
1. CHECK FOR EXISTING TEMPLATE
   └─ Look for .github/PULL_REQUEST_TEMPLATE.md

2. DECIDE SOURCE
   ├─ If no template exists → use default
   └─ If template exists → ask user: keep existing or replace?

3. INSTALL TEMPLATE
   ├─ mkdir -p .github
   └─ Copy default template to .github/PULL_REQUEST_TEMPLATE.md

4. SAVE CONFIG
   └─ Write pr-create.yaml with template source and path
```

### Save Location

Config path depends on the installation model. Detect which model is active by checking whether this skill is running from inside `.claude/skills/pr-create/` (my-workflow) or from an external plugin directory (standalone).

| Installation Model | Config File | How to Detect |
|--------------------|-------------|---------------|
| **Standalone** (external plugin) | `.claude/skills/pr-create.yaml` | Skill files are NOT inside `.claude/skills/pr-create/` |
| **my-workflow** (copied into project) | `.claude/skills/pr-create/pr-create.yaml` | Skill files ARE inside `.claude/skills/pr-create/` |

**Precedence when reading** (first found wins):
1. `.claude/skills/pr-create/pr-create.yaml` (my-workflow installation)
2. `.claude/skills/pr-create.yaml` (standalone installation)
3. Skill defaults

### Config Schema

```yaml
# .claude/skills/pr-create.yaml (standalone installation)
# .claude/skills/pr-create/pr-create.yaml (my-workflow installation)
version: 1
configured_at: "ISO timestamp"
template:
  source: "default"  # or "project"
  path: ".github/PULL_REQUEST_TEMPLATE.md"
```

---

## /pr-create (Normal Usage)

**When**: Creating a pull request

**Reads config from** (first found):
1. `.claude/skills/pr-create/pr-create.yaml` (my-workflow installation)
2. `.claude/skills/pr-create.yaml` (standalone installation)
3. Skill defaults

## Workflow

```
1. PRE-PR CHECKS
   ├─ Verify gh CLI installed and authenticated
   ├─ Verify on feature branch (not main/master)
   └─ Verify changes are committed

2. GENERATE PR CONTENT
   ├─ Analyze commits on branch
   ├─ Generate title (conventional commit format)
   └─ Generate body (use .github/PULL_REQUEST_TEMPLATE.md if exists)

3. VALIDATE (before creating)
   ├─ Check title for AI attribution (STOP if found)
   ├─ Check body for AI attribution (STOP if found)
   └─ Check title length ≤ 50 chars

4. USER REVIEW
   └─ Show preview, wait for approval

5. CREATE PR
   └─ gh pr create with approved content
```

## Prerequisites

Before creating a PR, verify:
1. **gh CLI installed**: `gh --version` - if missing: `brew install gh`
2. **gh CLI authenticated**: `gh auth status` - if not: `gh auth login`

## PR Title Format

```
<type>(<scope>): <subject>
```

### Types

| Type | Use for |
|------|---------|
| `feat` | New features |
| `fix` | Bug fixes |
| `chore` | Maintenance, refactoring |
| `docs` | Documentation |
| `test` | Test changes |
| `perf` | Performance improvements |
| `ci` | CI/CD changes |

### Scopes

Scopes are optional and project-specific. Common patterns:
- Module/package names (e.g., `auth`, `api`, `db`)
- Feature areas (e.g., `config`, `logging`)
- Service names (e.g., `worker`, `gateway`)

### Title Rules

1. Max 50 characters
2. Capitalized first letter after colon
3. No period at the end
4. Be specific - avoid "improve", "enhance", "update"
5. **NO AI ATTRIBUTION** - STRICTLY FORBIDDEN

## AI Attribution Policy

**COMPLETE VIOLATION** - Never include ANY of the following in PR titles, bodies, or commits:
- `Co-Authored-By: Claude`, `Co-Authored-By: GPT`, or any AI name
- AI-related emojis
- "Generated by", "Created with", or similar phrases
- Any reference to AI tools (Claude, ChatGPT, Copilot, etc.)

PRs and commits must appear as human-authored work. This is a strict framework requirement.

## PR Body Template

Use the PR template at `.github/PULL_REQUEST_TEMPLATE.md` if it exists.

Run `/pr-create configure` to install a default template if the project doesn't have one.

## User Review Step

Before creating the PR, present it to the user for review:

```
## PR Preview

**Title:** feat(auth): Add OAuth2 login support

**Body:**
## Description

Adds OAuth2 authentication via Google and GitHub providers.
Users can now log in with their existing accounts.

## Types of Changes

- [ ] Bug fix
- [x] New feature
...

---
Any changes I should make?
```

Wait for user confirmation:
- If user says "no" or confirms → create the PR
- If user requests changes → incorporate feedback and show again

## Automation
See `skill.yaml` for the full procedure and patterns.
See `sharp-edges.yaml` for common failure modes.
