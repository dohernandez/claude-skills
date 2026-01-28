---
name: my-workflow
description: "Install curated skill tiers into any project from the marketplace. Use when user says /my-workflow."
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
---

# My Workflow

## Purpose

Marketplace skill installer for the claude-skills ecosystem. Copies skills from the marketplace plugin cache into the current project's `.claude/skills/` directory. Three curated tiers provide progressively more capability.

## Quick Reference

- **Install tier**: `/my-workflow install minimal|standard|advanced`
- **Install one**: `/my-workflow install <skill-name>`
- **Browse**: `/my-workflow list`
- **Check**: `/my-workflow status`

## Commands

| Command | Purpose |
|---------|---------|
| `/my-workflow install` | Interactive wizard — choose tier or individual skills |
| `/my-workflow install minimal` | Install 7 essential skills |
| `/my-workflow install standard` | Install 17 dev workflow skills |
| `/my-workflow install advanced` | Install all 22 skills |
| `/my-workflow install <skill>` | Install a single specific skill |
| `/my-workflow list` | Show tiers and their skills |
| `/my-workflow status` | Show installed vs available |

---

## Tiers

### Minimal (7 skills) — Essential tooling

Needs: skill-tasks infrastructure (Taskfile.skills.yaml + scripts)

| Skill | Configure? |
|-------|-----------|
| commit | no |
| pr-create | no |
| pr-merge | no |
| linear | no |
| memory | no |
| create-skill | no |
| docs-refresh | yes |

### Standard (17 skills) — Complete dev workflow

Extends Minimal (+10 skills). Adds: user-tasks infrastructure (Taskfile.yaml)

| Added Skill | Configure? |
|-------------|-----------|
| code | yes |
| bugfix | no |
| tdd | yes |
| arch | yes |
| domain-expert | no |
| task | yes |
| test | yes |
| setup | no |
| deploy | yes |
| deploy-verify | yes |

### Advanced (22 skills) — Everything

Extends Standard (+5 skills).

| Added Skill | Configure? |
|-------------|-----------|
| developer | yes |
| workflow | no |
| workflow-setup | yes |
| workflow-finish | yes |
| debugger | yes |

**Excluded**: `slack` (planned for future release)

---

## /my-workflow install

### Parse command

```
/my-workflow install              -> interactive wizard
/my-workflow install minimal      -> install Minimal tier (7 skills)
/my-workflow install standard     -> install Standard tier (17 skills)
/my-workflow install advanced     -> install Advanced tier (22 skills)
/my-workflow install <skill-name> -> install single skill
```

### Interactive wizard (no argument)

1. Show all 3 tiers with descriptions and skill lists
2. Ask: "Choose a tier, or select individual skills?"
3. If tier: install that tier
4. If individual: show all 22 skills, let user pick

### Installation procedure

#### Step 1: Resolve marketplace root

Read the saved path from `.claude/skills/my-workflow/.marketplace-root`.

If the file doesn't exist, re-detect from `CLAUDE_PLUGIN_ROOT`:
- **Cache layout**: go up 2 directories from plugin root, look for sibling plugin dirs (commit/, pr-create/, etc.)
- **Local layout**: go up 2 directories, check for `plugins/` directory with known siblings

Save the detected path to `.marketplace-root` for future use.

#### Step 2: Determine layout

Check the marketplace root to determine skill source paths:

- **Cache layout**: `<root>/<skill-name>/<version>/skills/<skill-name>/`
  - Detect by checking if `<root>/commit/` exists (not `<root>/plugins/commit/`)
  - Find version by listing the version directory: `ls <root>/<skill-name>/`

- **Local layout**: `<root>/plugins/<skill-name>/skills/<skill-name>/`
  - Detect by checking if `<root>/plugins/commit/` exists

#### Step 3: Check already installed

For each skill in the target list:
- Check if `.claude/skills/<skill-name>/` exists
- If exists: mark as **skip**, report "Already installed: X (skipping)"
- If not: mark as **install**

**IMPORTANT**: Never overwrite existing skill directories. Users may have customized them.

#### Step 4: Install infrastructure

Determine which infrastructure is needed based on skills being installed:

| Infrastructure | Needed by | Files |
|---------------|-----------|-------|
| skill-tasks | create-skill, docs-refresh | Taskfile.skills.yaml + scripts/ |
| user-tasks | task, test, setup, developer | Taskfile.yaml + Taskfile.skills.yaml + scripts/ |

Note: user-tasks is a superset of skill-tasks. If both are needed, only install user-tasks.

Infrastructure source resolution:
1. Look for `infra/` directory at the marketplace root
2. If not found, download from `https://raw.githubusercontent.com/dohernandez/claude-skills/main/infra/`

Files to copy:
- `infra/Taskfile.yaml` → `.claude/Taskfile.yaml` (user-tasks only)
- `infra/Taskfile.skills.yaml` → `.claude/Taskfile.skills.yaml`
- `infra/scripts/*.sh` → `.claude/scripts/` (exclude setup.sh and post-install.sh)

Make all copied scripts executable with `chmod +x`.

#### Step 5: Copy skills

For each skill marked for installation:

```bash
# Resolve source path based on layout
# Cache: <root>/<skill>/<version>/skills/<skill>/
# Local: <root>/plugins/<skill>/skills/<skill>/

# Copy to project
cp -rL "$source" ".claude/skills/<skill-name>/"
```

Report each: `Installed: <skill-name>`

#### Step 6: Post-install configuration

Build a list of newly installed skills that support `/X configure`:
- docs-refresh, code, tdd, arch, task, test, deploy, deploy-verify, developer, workflow-setup, workflow-finish, debugger

For each configurable skill that was just installed:
- Ask: "Run /<skill> configure now? [y/n]"
- If yes: tell user to run `/<skill> configure`
- If no: add to unconfigured list

Show summary at the end:
```
Unconfigured skills: code, tdd, arch
Run /<skill> configure to set up each one.
```

---

## /my-workflow list

Display all tiers with their skills:

```
Minimal (7 skills) — Essential tooling
  commit, pr-create, pr-merge, linear, memory, create-skill, docs-refresh(*)

Standard (17 skills) — Complete dev workflow
  Minimal + code(*), bugfix, tdd(*), arch(*), domain-expert, task(*), test(*),
  setup, deploy(*), deploy-verify(*)

Advanced (22 skills) — Everything
  Standard + developer(*), workflow, workflow-setup(*), workflow-finish(*), debugger(*)

(*) = supports /X configure
```

---

## /my-workflow status

Check installed skills and show coverage:

```
1. Scan .claude/skills/ for directories
2. Match against all 22 known skills
3. Show installed vs available
4. Calculate tier coverage
5. Show infrastructure status (check for Taskfile.yaml, Taskfile.skills.yaml)
```

---

## Infrastructure Details

### skill-tasks

Required by: create-skill, docs-refresh

Provides skill validation and management tasks:
- `Taskfile.skills.yaml` — Task definitions for skill validation
- `scripts/` — Shell scripts for validation, auditing, structure checks

### user-tasks

Required by: task, test, setup, developer

Provides everything in skill-tasks PLUS:
- `Taskfile.yaml` — User-facing task definitions

### Source resolution

Infrastructure files come from the `infra/` directory:

1. **Local**: `<marketplace-root>/infra/` (for local dev)
2. **Local (cache)**: `<marketplace-root>/../infra/` (sometimes framework is a sibling)
3. **GitHub fallback**: Download from `https://raw.githubusercontent.com/dohernandez/claude-skills/main/infra/`

---

## Rules

- **Never overwrite** existing skill directories — skip and report
- **Always install infrastructure** before skills that need it
- **Detect layout dynamically** — never hardcode paths
- **user-tasks includes skill-tasks** — don't install both separately
- **Offer configure** for every configurable skill after installation
- **Report clearly** what was installed, skipped, and what needs configuration
