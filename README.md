# Claude Code Plugins

Developer workflow plugins for Anthropic's Claude Code. This repository is a marketplace of plugins that can be installed into your Claude Code projects.

## Overview

Skills are structured configuration files that guide AI assistants through complex operational procedures. They encode best practices, workflows, and domain knowledge that can be shared across projects.

## Quick Start

```bash
# Add the marketplace (once)
/plugin marketplace add https://github.com/genlayerlabs/skills.git

# Install full framework (22 skills)
/plugin install framework@genlayerlabs-skills

# Or install individual skills
/plugin install commit@genlayerlabs-skills
/plugin install linear@genlayerlabs-skills
```

## Available Plugins

| Plugin | Skills | Description |
|--------|--------|-------------|
| `framework` | 22 | Complete developer workflow framework |
| `commit` | 1 | Git commits with conventional commit format |
| `linear` | 1 | Linear issue management and ticket workflows |
| `pr-create` | 1 | Create GitHub pull requests with standardized format |
| `pr-merge` | 1 | Merge GitHub pull requests with proper validation |
| `node-installer` | 1 | Node.js version management (standalone) |

## Installation

### Option A: Install Full Framework (22 skills)

```bash
# Add the marketplace
/plugin marketplace add https://github.com/genlayerlabs/skills.git

# Install the framework plugin
/plugin install framework@genlayerlabs-skills
```

This installs all 22 framework skills (2 meta + 11 core + 9 customizable).

**After installation:**
```bash
# Validate prerequisites
claude --init

# Configure the framework
/framework:configure
```

### Option B: Install Individual Skills

```bash
# Add the marketplace (if not already added)
/plugin marketplace add https://github.com/genlayerlabs/skills.git

# Install specific skill plugins
/plugin install commit@genlayerlabs-skills
/plugin install linear@genlayerlabs-skills
```

**After installation:**
```bash
# Use the skill (namespaced by plugin)
/commit:commit
/linear:linear
```

### Option C: Install Standalone Plugins

Standalone plugins are not part of the framework bundle:

```bash
/plugin install node-installer@genlayerlabs-skills
```

## Skill Namespacing

Skills are namespaced by their plugin name:

| Installed Plugin | Skill Invocation |
|------------------|------------------|
| `framework` | `/framework:commit`, `/framework:linear`, etc. |
| `commit` | `/commit:commit` |
| `linear` | `/linear:linear` |

**Note:** If you install the full `framework` plugin, use `/framework:commit`. If you install the individual `commit` plugin, use `/commit:commit`.

## Installation Behavior

| Step | Framework Install | Individual Install |
|------|-------------------|-------------------|
| 1. Add marketplace | `/plugin marketplace add .../skills.git` | Same |
| 2. Install plugin | `/plugin install framework@...` | `/plugin install commit@...` |
| 3. Validate | `claude --init` | `claude --init` |
| 4. Configure | `/framework:configure` | (if skill has configure) |

**Key principle:** Configuration is a separate step after installation.

**Why separate steps?**
- Claude Code plugins don't have automatic post-install wizards
- Users have full control over what gets configured
- Configuration can be re-run anytime to update settings

## Framework Skills (22)

### Meta Skills (2) - Framework management

| Skill | Command | Description |
|-------|---------|-------------|
| `framework` | `/framework:framework` | Configure framework after installation |
| `create-skill` | `/framework:create-skill` | Create new skills following the architecture |

### Core Skills (11) - Drop-in, no customization needed

| Skill | Command | Description |
|-------|---------|-------------|
| `commit` | `/framework:commit` | Git commit with conventional commit format |
| `pr-create` | `/framework:pr-create` | Create pull requests with standardized format |
| `pr-merge` | `/framework:pr-merge` | Merge pull requests with proper validation |
| `bugfix` | `/framework:bugfix` | Structured bug investigation and fix workflow |
| `task` | `/framework:task` | Task execution and management workflow |
| `tdd` | `/framework:tdd` | Test-driven development workflow |
| `workflow` | `/framework:workflow` | Main development workflow orchestrator |
| `workflow-setup` | `/framework:workflow-setup` | Initialize workflow with branch creation |
| `workflow-finish` | `/framework:workflow-finish` | Complete workflow with cleanup |
| `linear` | `/framework:linear` | Linear issue management and ticket workflows |
| `slack` | `/framework:slack` | Slack integration for notifications |

### Customizable Skills (9) - Have configure mode

| Skill | Command | Description |
|-------|---------|-------------|
| `arch` | `/framework:arch` | Architecture guidance and validation |
| `code` | `/framework:code` | Code style configuration and enforcement |
| `developer` | `/framework:developer` | Development orchestration with domain understanding |
| `docs-refresh` | `/framework:docs-refresh` | Documentation generation and maintenance |
| `setup` | `/framework:setup` | Project setup and onboarding |
| `domain-expert` | `/framework:domain-expert` | Domain knowledge and terminology |
| `debugger` | `/framework:debugger` | Debugging workflow with systematic investigation |
| `deploy` | `/framework:deploy` | Deployment workflow |
| `deploy-verify` | `/framework:deploy-verify` | Post-deployment verification |

## Standalone Plugins

Skills not part of the framework bundle:

| Plugin | Skill | Description |
|--------|-------|-------------|
| `node-installer` | `/node-installer:node-installer` | Node.js version management and installation |

## Configuration Model

Skills follow a **configure/learn** pattern for project-specific setup:

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/plugin:skill configure` | Initial setup - scans project, proposes config | After install |
| `/plugin:skill learn` | Update config from new context | When project changes |
| `/plugin:skill` | Normal usage with saved config | Daily use |

### Example: TDD Skill

```bash
# First time setup (after framework install)
/framework:tdd configure
  → Scans project for test patterns
  → Proposes config (framework, locations, assertions)
  → Saves to .claude/skills/tdd.yaml

# Later, after adding new test patterns
/framework:tdd learn
  → Updates config with new patterns

# Normal usage
/framework:tdd
  → Uses saved config for consistent TDD workflow
```

## Repository Structure

```
skills/                              # Claude Code Plugins Marketplace
├── .claude-plugin/
│   └── marketplace.json             # Lists all available plugins
│
├── framework/                       # Full framework plugin (22 skills)
│   ├── .claude-plugin/plugin.json
│   ├── skills/                      # All framework skills
│   │   ├── commit/
│   │   ├── linear/
│   │   └── ...
│   ├── hooks/
│   └── scripts/
│
└── plugins/                         # Individual skill plugins
    ├── commit/                      # Commit skill only
    │   ├── .claude-plugin/plugin.json
    │   └── skills/commit -> ../../framework/skills/commit
    ├── linear/
    ├── pr-create/
    ├── pr-merge/
    └── node-installer/              # Standalone (not in framework)
        ├── .claude-plugin/plugin.json
        └── skills/node-installer/
```

## Skill Architecture

Each skill directory contains:

| File | Required | Purpose |
|------|----------|---------|
| `SKILL.md` | Yes | Human-readable documentation with frontmatter |
| `skill.yaml` | Yes | Machine-readable procedure definition |
| `validations.yaml` | No | Automated checks (on_stop, on_warn) |
| `sharp-edges.yaml` | No | Known edge cases to check proactively |
| `collaboration.yaml` | No | Dependencies and trigger patterns |

### SKILL.md Frontmatter

```yaml
---
name: commit
description: "Create git commits with conventional commit messages."
user-invocable: true
allowed-tools:
  - Read
  - Bash
  - Glob
---
```

### skill.yaml Structure

```yaml
name: commit
kind: action          # action, workflow, methodology, utility, integration
version: "2.0.0"
description: "..."

purpose: |
  What this skill does and why.

procedure:
  - step: "Step 1"
    detail: "What to do"
    commands: ["cmd1", "cmd2"]

patterns:
  - id: pattern-name
    description: "..."

anti_patterns:
  - id: anti-pattern-name
    description: "..."
    why_bad: "..."
```

## Creating New Skills

Use the `create-skill` skill:

```bash
/framework:create-skill my-new-skill
```

Or manually:

1. Create directory: `framework/skills/my-skill/`
2. Add `SKILL.md` with frontmatter
3. Add `skill.yaml` with procedure
4. Add `validations.yaml` (optional)

## Requirements

- Claude Code CLI
- [Task](https://taskfile.dev/) (for framework infrastructure)
- Bash 3.2+ (macOS/Linux)

## License

MIT License - see LICENSE file for details.
