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
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill create-skill"
---

# Create Skill

## Purpose

Scaffold a new `.claude/skills/{folder-name}/` skill directory that follows the multi-YAML pattern. Produces the canonical file set and wires the Stop hook to `task claude:validate-skill`.

## Quick Reference

- **Creates:** SKILL.md, skill.yaml, validations.yaml, sharp-edges.yaml, collaboration.yaml
- **Requires:** folder name, description, purpose
- **Stop hook:** `task claude:validate-skill -- --skill {folder-name}`

## Skill File Structure

Each skill directory contains:

| File | Purpose |
|------|---------|
| `SKILL.md` | Human-readable documentation (thin wrapper) |
| `skill.yaml` | Machine-readable procedure, patterns, anti-patterns |
| `validations.yaml` | Automated checks for Stop hook |
| `sharp-edges.yaml` | Edge cases and gotchas |
| `collaboration.yaml` | Dependencies and triggers |

## Workflow

1. **Discover operations** - Run `task --list` to find available validation targets
2. **Gather inputs** - folder name, title, description, purpose
3. **Create folder** - `mkdir -p .claude/skills/{folder-name}/`
4. **Write files** - Create all 5 canonical files
5. **Validate** - Run `task claude:validate-skill -- --skill {folder-name}`

## Rules

- [ ] Folder name must match SKILL.md frontmatter `name:`
- [ ] SKILL.md should be thin (pointer-level only)
- [ ] validations.yaml must only reference existing Task targets
- [ ] Stop hook must call `task claude:validate-skill -- --skill {folder-name}`

## Automation

See `skill.yaml` for the full procedure and patterns.
See `sharp-edges.yaml` for common failure modes.
