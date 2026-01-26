---
name: framework
description: "Configure the Claude Code Developer Framework. Use when user says /framework or /framework configure."
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Framework Configuration

## Purpose

Configure the Claude Code Developer Framework after installation. This skill orchestrates the configuration of all framework skills.

## When to Use

- After installing the framework plugin: `/plugin install anthropic@genlayerlabs-skills`
- After running `claude --init`
- When re-configuring the framework for a project
- When user says `/framework` or `/framework configure`

## Commands

| Command | Purpose |
|---------|---------|
| `/framework configure` | Run full configuration wizard |
| `/framework status` | Show current configuration status |

## Configuration Workflow

### Phase 1: Framework-Level Configuration

Ask for project-level settings and save to `.claude/skills-config.env`:

```
PROJECT_NAME=<project-name>
LINT_COMMAND=<lint-command>
TEST_COMMAND=<test-command>
PRECOMMIT_COMMAND=<precommit-command>
```

**Questions to ask:**

1. **PROJECT_NAME** (required): "What is your project name?"
2. **LINT_COMMAND** (optional): "What command runs your linter? (e.g., npm run lint, task lint)"
3. **TEST_COMMAND** (optional): "What command runs your tests? (e.g., npm test, task test)"
4. **PRECOMMIT_COMMAND** (optional): "What command runs pre-commit checks? (leave blank for lint + test)"

### Phase 2: Skill-Level Configuration

For each skill that has `configure: true` in the manifest, run its configure command.

**Skills requiring configuration (in order):**

1. `/arch configure` - Architecture style and layers
2. `/code configure` - Code style from linter configs
3. `/tdd configure` - Test framework and patterns
4. `/commit configure` - Commit scopes from project structure
5. `/developer configure` - Development patterns
6. `/domain configure` - Domain knowledge
7. `/workflow configure` - Worktree and IDE preferences
8. `/deploy configure` - Deployment commands
9. `/deploy-verify configure` - Verification endpoints
10. `/debugger configure` - Log commands
11. `/docs-refresh configure` - Documentation paths
12. `/setup configure` - Setup commands
13. `/linear configure` - Linear workspace (if using Linear)

**For each skill:**
1. Announce: "Configuring <skill>..."
2. Run the skill's configure procedure
3. Wait for user confirmation
4. Move to next skill

### Phase 3: Verification

After all skills are configured:

1. Show summary of configured skills
2. Show location of config files
3. Remind user they can re-configure individual skills anytime

## Output Format

```
╔══════════════════════════════════════════════════════════════╗
║  Claude Code Developer Framework - Configuration Wizard      ║
╚══════════════════════════════════════════════════════════════╝

Phase 1: Framework Configuration
────────────────────────────────
PROJECT_NAME: my-project
LINT_COMMAND: npm run lint
TEST_COMMAND: npm test
PRECOMMIT_COMMAND: (using lint + test)

✓ Saved to .claude/skills-config.env

Phase 2: Skill Configuration
────────────────────────────
[1/13] Configuring arch...
  → Architecture style: hexagonal
  → Layers: domain, application, infrastructure
  ✓ Saved to .claude/skills/arch.yaml

[2/13] Configuring code...
  → Detected: biome.json, .editorconfig
  ✓ Saved to .claude/skills/code.yaml

... (continue for each skill)

Phase 3: Summary
────────────────
✓ Framework configured successfully!

Config files created:
  • .claude/skills-config.env (framework settings)
  • .claude/skills/arch.yaml
  • .claude/skills/code.yaml
  • .claude/skills/tdd.yaml
  ... (list all)

To re-configure a specific skill:
  /arch configure
  /tdd configure
  etc.
```

## Status Command

When user runs `/framework status`:

```
╔══════════════════════════════════════════════════════════════╗
║  Framework Configuration Status                              ║
╚══════════════════════════════════════════════════════════════╝

Framework Config: .claude/skills-config.env
  PROJECT_NAME: my-project ✓
  LINT_COMMAND: npm run lint ✓
  TEST_COMMAND: npm test ✓
  PRECOMMIT_COMMAND: (default) ✓

Skill Configurations:
  ✓ arch        .claude/skills/arch.yaml
  ✓ code        .claude/skills/code.yaml
  ✓ tdd         .claude/skills/tdd.yaml
  ✗ commit      Not configured
  ✗ developer   Not configured
  ...

Run /framework configure to configure missing skills.
```

## Error Handling

- If a skill's configure fails, log the error and continue with next skill
- At the end, show list of skills that failed configuration
- User can re-run individual skill configure commands

## Notes

- This skill is included in the framework bundle but can also be invoked after individual skill installation
- When installing a single skill that requires configuration, the install process should prompt to run `/skill configure`
