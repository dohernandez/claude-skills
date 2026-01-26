---
name: framework
description: "Install and configure Claude Code skills. Use when user says /framework."
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

# Framework - Skill Installation Orchestrator

## Purpose

Install, manage, and configure Claude Code skills from the dohernandez-claude-skills marketplace. The framework acts as an orchestrator that installs individual skill plugins based on your selected tier.

## Marketplace

All skills are available from: `dohernandez-claude-skills`

## Commands

| Command | Purpose |
|---------|---------|
| `/framework install <tier>` | Install skills by tier (minimal, standard, full) |
| `/framework install <skills>` | Install specific skills (comma-separated) |
| `/framework uninstall <skill>` | Uninstall a specific skill |
| `/framework uninstall --all` | Remove ALL skills and infrastructure |
| `/framework list` | Show installed skills and their status |
| `/framework update` | Update all installed skills |
| `/framework configure` | Configure installed skills |
| `/framework status` | Show configuration status |

## Skill Tiers

| Tier | Count | Skills |
|------|-------|--------|
| **minimal** | 11 | commit, create-skill, docs-refresh, linear, pr-create, pr-merge, setup, task, bugfix, workflow-finish, workflow-setup |
| **standard** | 16 | minimal + deploy, deploy-verify, developer, code, test |
| **full** | 22 | All available skills |

## Installation Workflow

### `/framework install <tier>`

Installs all skills in the specified tier using `claude plugin install`.

```
╔══════════════════════════════════════════════════════════════╗
║  Claude Code Skills - Installation                           ║
╚══════════════════════════════════════════════════════════════╝

Installing tier: minimal (11 skills)
──────────────────────────────────────

Scope: project (shared via git)

[1/11] Installing commit...
  → claude plugin install commit@dohernandez-claude-skills --scope project
  ✓ Installed

[2/11] Installing create-skill...
  → claude plugin install create-skill@dohernandez-claude-skills --scope project
  ✓ Installed

... (continues for all skills)

Summary
───────
✓ Installed: 11 skills
✗ Failed: 0 skills

Skills are now available as: /commit, /pr-create, /test, etc.

Next steps:
  /framework configure  - Configure installed skills
  /framework list       - View installed skills
```

### `/framework install <skills>`

Install specific skills by name (comma-separated).

```bash
# Examples
/framework install commit,pr-create,pr-merge
/framework install tdd,test
```

### Scope Selection

Before installation, ask the user which scope to use:

| Scope | Location | Git Shared | Use Case |
|-------|----------|------------|----------|
| **project** (Recommended) | `.claude/settings.json` | Yes | Team projects |
| **local** | `.claude/settings.local.json` | No (gitignored) | Personal additions |
| **user** | `~/.claude/settings.json` | No | Global installation |

## Uninstall

### `/framework uninstall <skill>`

Remove a specific skill.

```
Uninstalling: commit
  → claude plugin uninstall commit@dohernandez-claude-skills --scope project
  ✓ Uninstalled

Note: Configuration file .claude/skills/commit.yaml preserved.
      Delete manually if no longer needed.
```

### `/framework uninstall --all`

Remove ALL skills and shared infrastructure. **This is the recommended way to completely remove the framework.**

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

[2/11] Uninstalling pr-create...
  → claude plugin uninstall pr-create@dohernandez-claude-skills
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

Note: Configuration files in .claude/skills/*.yaml preserved.
      Delete .claude/skills/ manually if no longer needed.
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

**To clean up manually after direct uninstall:**

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

**Note:** The infrastructure files are harmless if left behind. They don't affect other plugins or Claude Code functionality.

## List Installed Skills

### `/framework list`

Show all installed skills from this marketplace.

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

Install more: /framework install <skill>
Install tier: /framework install standard
```

## Update Skills

### `/framework update`

Update all installed skills to latest version.

```
╔══════════════════════════════════════════════════════════════╗
║  Updating Skills                                             ║
╚══════════════════════════════════════════════════════════════╝

[1/11] Updating commit...
  → claude plugin update commit@dohernandez-claude-skills
  ✓ Updated

... (continues for all installed skills)

Summary
───────
✓ Updated: 11 skills
```

## Configuration Workflow

### `/framework configure`

Configure installed skills. Only shows skills that are actually installed.

```
╔══════════════════════════════════════════════════════════════╗
║  Claude Code Skills - Configuration                          ║
╚══════════════════════════════════════════════════════════════╝

Phase 1: Framework Configuration
────────────────────────────────
PROJECT_NAME: my-project
LINT_COMMAND: npm run lint
TEST_COMMAND: npm test
PRECOMMIT_COMMAND: (none)

✓ Saved to .claude/skills-config.env

Phase 2: Skill Configuration
────────────────────────────
Configuring installed skills...

[1/5] commit - Configure? [Configure / Skip]
  → Configured: conventional commits, scopes: api, core, infra
  ✓ Saved to .claude/skills/commit.yaml

[2/5] linear - Configure? [Configure / Skip]
  → Skipped (usable with defaults)

... (continues for configurable skills)

Phase 3: Summary
────────────────
✓ Configuration complete!

Configured:
  • commit        .claude/skills/commit.yaml
  • docs-refresh  .claude/skills/docs-refresh.yaml

Skipped (using defaults):
  • linear
  • setup

To re-configure: /<skill> configure
```

## Status

### `/framework status`

Show current installation and configuration status.

```
╔══════════════════════════════════════════════════════════════╗
║  Framework Status                                            ║
╚══════════════════════════════════════════════════════════════╝

Marketplace: dohernandez-claude-skills

Installation:
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
  /framework install standard  - Upgrade to standard tier
  /framework configure         - Configure more skills
  /framework update           - Update all skills
```

## Implementation Details

### Install Command

For each skill in the tier, run:

```bash
claude plugin install <skill>@dohernandez-claude-skills --scope <scope>
```

### Check Installed Skills

To determine which skills are installed, check:

```bash
# List installed plugins and filter by marketplace
claude plugin list | grep dohernandez-claude-skills
```

Or read from settings files:
- Project: `.claude/settings.json`
- Local: `.claude/settings.local.json`
- User: `~/.claude/settings.json`

### Skill Plugin Names

All skills follow the pattern: `<skill-name>@dohernandez-claude-skills`

Examples:
- `commit@dohernandez-claude-skills`
- `pr-create@dohernandez-claude-skills`
- `tdd@dohernandez-claude-skills`

## Error Handling

- If a skill installation fails, log the error and continue with next skill
- At the end, show summary of successful and failed installations
- User can retry failed skills individually

## Notes

- Skills can be installed individually without using the framework
- The framework just provides convenient tier-based installation
- Each skill is a standalone plugin with its own version
- Configuration files are separate from plugin installation
