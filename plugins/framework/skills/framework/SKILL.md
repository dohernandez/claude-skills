---
name: framework
description: "Install and configure Claude Code skills. Use when user says /framework or /framework configure."
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
hooks:
  Stop:
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill framework"
---

# Framework - Skill Installation & Configuration

## Purpose

Install and configure Claude Code skills from the dohernandez-claude-skills marketplace. The framework orchestrates tier-based skill installation and configuration in a single wizard.

## Marketplace

All skills are available from: `dohernandez-claude-skills`

## Commands

| Command | Purpose |
|---------|---------|
| `/framework configure` | **Main command** - Install skills by tier + configure |
| `/framework install <skills>` | Add specific skills (comma-separated) |
| `/framework uninstall <skill>` | Remove a specific skill |
| `/framework uninstall --all` | Remove ALL skills and infrastructure |
| `/framework list` | Show installed skills and their status |
| `/framework update` | Update all installed skills |
| `/framework status` | Show configuration status |

## Skill Tiers

| Tier | Count | Skills |
|------|-------|--------|
| **minimal** | 11 | commit, create-skill, docs-refresh, linear, pr-create, pr-merge, setup, task, bugfix, workflow-finish, workflow-setup |
| **standard** | 16 | minimal + deploy, deploy-verify, developer, code, test |
| **full** | 22 | All available skills |

---

## /framework configure (Main Wizard)

This is the primary command. It handles both installation AND configuration.

```
╔══════════════════════════════════════════════════════════════╗
║  Claude Code Skills - Setup Wizard                           ║
╚══════════════════════════════════════════════════════════════╝
```

### Phase 0: Tier Selection & Installation

```
Phase 0: Tier Selection
───────────────────────
Which skill tier do you want?

1. Minimal (Recommended) - 11 skills
   commit, create-skill, docs-refresh, linear, pr-create, pr-merge,
   setup, task, bugfix, workflow-finish, workflow-setup

2. Standard - 16 skills
   Minimal + deploy, deploy-verify, developer, code, test

3. Full - 22 skills
   All available skills

Selected: Minimal

Scope Selection
───────────────
Where should skills be installed?

1. project (Recommended) - Shared with team via .claude/settings.json
2. local - Project-only, gitignored
3. user - Global installation

Selected: project

Installing skills...
────────────────────
[1/11] Installing commit...
  → claude plugin install commit@dohernandez-claude-skills --scope project
  ✓ Installed

[2/11] Installing create-skill...
  → claude plugin install create-skill@dohernandez-claude-skills --scope project
  ✓ Installed

... (continues for all skills in tier)

✓ Installed 11 skills

Saved to .claude/skills-config.env:
  FRAMEWORK_TIER=minimal
  FRAMEWORK_SCOPE=project
```

### Phase 1: Framework Configuration

```
Phase 1: Framework Configuration
────────────────────────────────
PROJECT_NAME: my-project
LINT_COMMAND: npm run lint (optional)
TEST_COMMAND: npm test (optional)
PRECOMMIT_COMMAND: (none)

✓ Saved to .claude/skills-config.env
```

### Phase 2: Skill Configuration

```
Phase 2: Skill Configuration
────────────────────────────
Configuring installed skills...

[1/5] commit - Configure? [Configure / Skip]
  → Configured: conventional commits, scopes: api, core, infra
  ✓ Saved to .claude/skills/commit.yaml

[2/5] linear - Configure? [Configure / Skip]
  → Skipped (usable with defaults)

[3/5] docs-refresh - Configure? [Configure / Skip]
  → Configured: docs/ directory
  ✓ Saved to .claude/skills/docs-refresh.yaml

... (continues for configurable skills)
```

### Phase 3: Summary

```
Phase 3: Summary
────────────────
✓ Framework setup complete!

Tier: Minimal (11 skills installed)
Scope: project

Configured skills:
  • commit        .claude/skills/commit.yaml
  • docs-refresh  .claude/skills/docs-refresh.yaml

Skipped (using defaults):
  • linear
  • setup

Skills without configuration:
  • create-skill, pr-create, pr-merge, bugfix, workflow-finish, workflow-setup

Commands:
  /<skill>              - Use a skill
  /<skill> configure    - Re-configure a skill
  /framework install X  - Add more skills
  /framework status     - Check configuration
```

---

## /framework install <skills>

Add specific skills after initial setup. Use comma-separated names.

```bash
# Examples
/framework install tdd,test
/framework install arch,domain-expert
```

```
Installing additional skills...
───────────────────────────────
[1/2] Installing tdd...
  → claude plugin install tdd@dohernandez-claude-skills --scope project
  ✓ Installed

[2/2] Installing test...
  → claude plugin install test@dohernandez-claude-skills --scope project
  ✓ Installed

✓ Installed 2 additional skills

Run /framework configure to configure new skills.
```

---

## /framework list

Show installed skills and their status.

```
╔══════════════════════════════════════════════════════════════╗
║  Installed Skills                                            ║
╚══════════════════════════════════════════════════════════════╝

Scope: project

Installed (11):
  ✓ commit          Git commits with conventional format
  ✓ create-skill    Scaffold new skills
  ✓ docs-refresh    Documentation generation
  ✓ linear          Linear issue management
  ✓ pr-create       Create GitHub PRs
  ✓ pr-merge        Merge PRs with CI validation
  ✓ setup           Project setup
  ✓ task            Task execution
  ✓ bugfix          Bug investigation
  ✓ workflow-finish Complete workflow cleanup
  ✓ workflow-setup  Initialize workflow

Not installed (11):
  ○ arch            Architecture patterns
  ○ code            Code style enforcement
  ○ debugger        Production debugging
  ○ deploy          Deployment workflow
  ○ deploy-verify   Post-deployment verification
  ○ developer       Development orchestration
  ○ domain-expert   Domain knowledge
  ○ slack           Slack integration
  ○ tdd             Test-driven development
  ○ test            Smart test runner
  ○ workflow        Workflow orchestration

Add more: /framework install <skill>
```

---

## /framework update

Update all installed skills to latest version.

```
Updating skills...
──────────────────
[1/11] Updating commit...
  → claude plugin update commit@dohernandez-claude-skills
  ✓ Updated

... (continues for all installed skills)

✓ Updated 11 skills
```

---

## /framework status

Show current configuration status.

```
╔══════════════════════════════════════════════════════════════╗
║  Framework Status                                            ║
╚══════════════════════════════════════════════════════════════╝

Marketplace: dohernandez-claude-skills
Installed: 11 skills (minimal tier)
Scope: project

Framework Config: .claude/skills-config.env
  PROJECT_NAME: my-project ✓
  LINT_COMMAND: npm run lint ✓
  TEST_COMMAND: npm test ✓
  PRECOMMIT_COMMAND: (default) ✓

Skill Configurations:
  ✓ commit        .claude/skills/commit.yaml
  ✓ docs-refresh  .claude/skills/docs-refresh.yaml
  ○ linear        Not configured (using defaults)
  ○ setup         Not configured (using defaults)
  ○ task          Not configured (using defaults)

Commands:
  /framework install <skill>  - Add more skills
  /<skill> configure          - Configure a skill
```

---

## Uninstall

### `/framework uninstall <skill>`

Remove a specific skill. Reads `FRAMEWORK_SCOPE` from `.claude/skills-config.env` to determine which scope to use.

```
Uninstalling: commit
  Scope: project (from .claude/skills-config.env)
  → claude plugin uninstall commit@dohernandez-claude-skills --scope project
  ✓ Uninstalled

Note: Config file .claude/skills/commit.yaml preserved.
```

### `/framework uninstall --all`

Remove ALL skills and infrastructure. **Recommended way to completely remove the framework.**

```
╔══════════════════════════════════════════════════════════════╗
║  Framework Uninstall - Complete Removal                      ║
╚══════════════════════════════════════════════════════════════╝

This will remove:
  • All installed skills from dohernandez-claude-skills
  • Shared infrastructure (Taskfile, scripts)
  • Framework skill itself

Proceed? [Yes / No]

Uninstalling skills...
──────────────────────
[1/11] Uninstalling commit...
  → claude plugin uninstall commit@dohernandez-claude-skills
  ✓ Uninstalled

... (continues for all installed skills)

Removing shared infrastructure...
─────────────────────────────────
  ✓ Removed .claude/Taskfile.yaml
  ✓ Removed .claude/scripts/
  ✓ Removed .claude/skills/framework/

Uninstalling framework plugin...
────────────────────────────────
  → claude plugin uninstall framework@dohernandez-claude-skills
  ✓ Uninstalled

Summary
───────
✓ Uninstalled: 11 skills
✓ Removed: shared infrastructure
✓ Removed: framework plugin

Note: Config files in .claude/skills/*.yaml preserved.
```

### Direct Plugin Uninstall (Alternative)

If you uninstall the framework plugin directly via CLI:

```bash
claude plugin uninstall framework@dohernandez-claude-skills
```

**What happens:**
- ✓ Framework plugin is removed
- ✓ Individual skill plugins remain installed (they're separate plugins)
- ○ Shared infrastructure files remain (harmless):
  - `.claude/Taskfile.yaml`
  - `.claude/scripts/`
  - `.claude/skills/framework/`

**To clean up manually:**

```bash
# Remove individual skill plugins
claude plugin uninstall commit@dohernandez-claude-skills
claude plugin uninstall pr-create@dohernandez-claude-skills
# ... repeat for each installed skill

# Remove infrastructure files
rm -f .claude/Taskfile.yaml
rm -rf .claude/scripts/
rm -rf .claude/skills/framework/

# Optionally remove skill configs
rm -rf .claude/skills/*.yaml
```

**Note:** The infrastructure files are harmless if left behind.

---

## Implementation Details

### Install Command

For each skill in the tier, run:

```bash
claude plugin install <skill>@dohernandez-claude-skills --scope <scope>
```

### Check Installed Skills

Read from settings files:
- Project: `.claude/settings.json`
- Local: `.claude/settings.local.json`
- User: `~/.claude/settings.json`

Filter for plugins matching: `*@dohernandez-claude-skills`

### Skill Plugin Names

Pattern: `<skill-name>@dohernandez-claude-skills`

Examples:
- `commit@dohernandez-claude-skills`
- `pr-create@dohernandez-claude-skills`
- `tdd@dohernandez-claude-skills`

## Error Handling

- If a skill installation fails, log the error and continue with next skill
- At the end, show summary of successful and failed installations
- User can retry failed skills with `/framework install <skill>`
