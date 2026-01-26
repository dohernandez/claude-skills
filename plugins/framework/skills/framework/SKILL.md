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
hooks:
  Stop:
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill framework"
---

# Framework Configuration

## Purpose

Configure the Claude Code Developer Framework after installation. This skill orchestrates the configuration of all framework skills.

## When to Use

- After installing the framework plugin: `/plugin install anthropic@dohernandez-claude-skills`
- After running `claude --init`
- When re-configuring the framework for a project
- When user says `/framework` or `/framework configure`

## Commands

| Command | Purpose |
|---------|---------|
| `/framework configure` | Run full configuration wizard |
| `/framework status` | Show current configuration status |

## Configuration Workflow

### Phase 0: Tier Selection

Ask which skill tier the user wants:

| Tier | Skills | Description |
|------|--------|-------------|
| **Minimal** (Recommended) | 11 | commit, create-skill, docs-refresh, linear, pr-create, pr-merge, setup, task, bugfix, workflow-finish, workflow-setup |
| **Standard** | 16 | Minimal + deploy, deploy-verify, developer, code, test |
| **Full** | 23 | All available skills including arch, domain-expert, tdd, debugger, slack, workflow |

Save selected tier to `.claude/skills-config.env` as `FRAMEWORK_TIER`.

### Phase 1: Framework-Level Configuration

Ask for project-level settings and save to `.claude/skills-config.env`:

```
FRAMEWORK_TIER=<minimal|standard|full>
PROJECT_NAME=<project-name>
LINT_COMMAND=<lint-command>
TEST_COMMAND=<test-command>
TEST_WATCH_COMMAND=<test-watch-command>
TEST_COVERAGE_COMMAND=<test-coverage-command>
PRECOMMIT_COMMAND=<precommit-command>
```

**Questions to ask:**

1. **PROJECT_NAME** (required): "What is your project name?"
2. **LINT_COMMAND** (optional): "What command runs your linter? (e.g., npm run lint, task lint)"
3. **TEST_COMMAND** (optional): "What command runs your tests? (e.g., npm test, task test)"
4. **TEST_WATCH_COMMAND** (optional): "What command runs tests in watch mode? (e.g., npm test -- --watch)"
5. **TEST_COVERAGE_COMMAND** (optional): "What command runs tests with coverage? (e.g., npm test -- --coverage)"
6. **PRECOMMIT_COMMAND** (optional): "What command runs pre-commit checks? (leave blank for lint + test)"

### Phase 2: Skill-Level Configuration

For each skill in the selected tier, offer to configure or skip.

**IMPORTANT: All skills can be skipped**
- For each skill, ask: "Configure <skill>?" with options [Configure, Skip]
- **Skip**: Skill remains installed and usable with defaults, no config file created
- **Configure**: Run the skill's configure procedure

**Skills by tier:**

**Minimal tier (11 skills):**
1. `/commit configure` - Commit scopes
2. `/linear configure` - Linear workspace
3. `/docs-refresh configure` - Documentation paths
4. `/setup configure` - Setup commands
5. `/task configure` - Task management

**Standard tier adds (+5 skills):**
6. `/code configure` - Code style from linter configs
7. `/test configure` - Test framework
8. `/deploy configure` - Deployment commands
9. `/deploy-verify configure` - Verification endpoints
10. `/developer configure` - Development patterns (simple version)

**Full tier adds (+7 skills):**
11. `/arch configure` - Architecture style and layers
12. `/tdd configure` - Test framework and patterns
13. `/domain-expert configure` - Domain knowledge
14. `/debugger configure` - Log commands
15. `/workflow configure` - Worktree and IDE preferences
16. `/slack configure` - Slack integration

**For each skill:**
1. Ask: "Configure <skill>?" [Configure / Skip]
2. If Configure: Run the skill's configure procedure
3. If Skip: Continue to next skill
4. Show result (configured/skipped)

### Phase 3: Verification

After all skills are configured:

1. Show selected tier
2. Show summary of configured skills
3. Show skipped skills (usable with defaults)
4. Show location of config files
5. Remind user they can re-configure individual skills anytime

## Output Format

```
╔══════════════════════════════════════════════════════════════╗
║  Claude Code Developer Framework - Configuration Wizard      ║
╚══════════════════════════════════════════════════════════════╝

Phase 0: Tier Selection
───────────────────────
Which skill tier do you want?
1. Minimal (Recommended) - 11 skills
   commit, create-skill, docs-refresh, linear, pr-create, pr-merge,
   setup, task, bugfix, workflow-finish, workflow-setup
2. Standard - 16 skills
   Minimal + deploy, deploy-verify, developer, code, test
3. Full - 23 skills
   All available skills

Selected: Minimal

Phase 1: Framework Configuration
────────────────────────────────
PROJECT_NAME: my-project
LINT_COMMAND: (none)
TEST_COMMAND: (none)
PRECOMMIT_COMMAND: (none)

✓ Saved to .claude/skills-config.env

Phase 2: Skill Configuration
────────────────────────────
[1/5] commit - Configure? [Configure / Skip]
  → Configured: conventional commits, scopes: api, core, infra
  ✓ Saved to .claude/skills/commit.yaml

[2/5] linear - Configure? [Configure / Skip]
  → Skipped (usable with defaults)

[3/5] docs-refresh - Configure? [Configure / Skip]
  → Configured: docs/ directory
  ✓ Saved to .claude/skills/docs-refresh.yaml

... (continue for each skill in tier)

Phase 3: Summary
────────────────
✓ Framework configured successfully!

Tier: Minimal (11 skills)

Configured skills:
  • commit        .claude/skills/commit.yaml
  • docs-refresh  .claude/skills/docs-refresh.yaml
  • setup         .claude/skills/setup.yaml

Skipped skills (usable with defaults):
  • linear
  • task

Skills without configuration:
  • create-skill, pr-create, pr-merge, bugfix, workflow-finish, workflow-setup

To re-configure a specific skill:
  /commit configure
  /linear configure
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
  TEST_WATCH_COMMAND: npm test -- --watch ✓
  TEST_COVERAGE_COMMAND: npm test -- --coverage ✓
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
