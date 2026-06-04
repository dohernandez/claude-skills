---
name: create-skill
description: Scaffold a new Claude Code skill directory. Use when user says /create-skill.
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
hooks:
  Stop:
    - matcher: "*"
      hooks:
        - type: command
          command: "bash ${CLAUDE_PLUGIN_ROOT}/infra/install-and-validate.sh"
---

# Create Skill

## Purpose

Scaffold a new `.claude/skills/{folder-name}/` skill directory that follows the multi-YAML pattern. Produces the canonical file set in the current project. Validation runs automatically on Stop using the plugin's own bundled infra — no project setup required.

## Quick Reference

- **Creates:** SKILL.md, skill.yaml, validations.yaml, sharp-edges.yaml, collaboration.yaml (in the project's `.claude/skills/{folder-name}/`)
- **Requires:** folder name, description, purpose
- **Validation:** automatic on Stop via `${CLAUDE_PLUGIN_ROOT}/infra/install-and-validate.sh`, which installs the bundled validation infra into the project's `.claude/` and runs the structure check.

## How validation works (global-install model)

This plugin is installed as a Claude Code plugin and auto-discovered — its files live in the plugin cache, not in the project. `${CLAUDE_PLUGIN_ROOT}` is only available to **hook processes**, not to the model's Bash calls, so:

- The **Stop hook** carries the validation infra (Taskfile + scripts) bundled at `${CLAUDE_PLUGIN_ROOT}/infra/`.
- On Stop it copies that infra into the project's `.claude/` (idempotent). That is what makes the Stop hooks of skills you *generate* work — they reference the now-present `.claude/Taskfile.skills.yaml`.
- Then it runs `check-structure` over the project's skills, including the one just created.

## Skill File Structure

Each skill directory contains:

| File | Purpose |
|------|---------|
| `SKILL.md` | Human-readable documentation (thin wrapper) |
| `skill.yaml` | Machine-readable procedure, patterns, anti-patterns |
| `validations.yaml` | Automated checks for the Stop hook |
| `sharp-edges.yaml` | Edge cases and gotchas |
| `collaboration.yaml` | Dependencies and triggers |

## Workflow

1. **Gather inputs** - folder name, title, description, purpose
2. **Create folder** - `mkdir -p .claude/skills/{folder-name}/`
3. **Write files** - Create all 5 canonical files
4. **Generated Stop hook** - give the new skill a Stop hook that calls
   `task -t .claude/Taskfile.skills.yaml validate-skill -- --skill {folder-name}`
   (the create-skill Stop hook installs that Taskfile into the project, so it resolves)
5. **Stop** - validation runs automatically; fix anything it reports

## Rules

- [ ] Folder name must match SKILL.md frontmatter `name:`
- [ ] SKILL.md should be thin (pointer-level only)
- [ ] validations.yaml must only reference existing Task targets
- [ ] A generated skill's Stop hook must call `task -t .claude/Taskfile.skills.yaml validate-skill -- --skill {folder-name}`
- [ ] This plugin's own validation infra is bundled under `infra/` and reached via `${CLAUDE_PLUGIN_ROOT}` from the Stop hook only

## Automation

See `skill.yaml` for the full procedure and patterns.
See `sharp-edges.yaml` for common failure modes.
