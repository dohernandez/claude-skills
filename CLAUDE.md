# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains **skills** - structured configuration files that guide AI assistants through complex operational procedures.

## Skill Architecture

Each skill lives in its own directory and is defined by multiple YAML/Markdown files:

- **SKILL.md** - Human-readable documentation with full procedure details, step-by-step instructions, and usage examples
- **skill.yaml** - Machine-readable procedure definition including inputs, patterns, anti-patterns, config wizard structure, and the main procedure flow
- **validations.yaml** - Automated checks (prerequisites, post-installation verification) with commands, expected results, and error messages
- **sharp-edges.yaml** - Known edge cases and gotchas with detection commands, impact descriptions, and fixes. These must be **proactively checked** during execution, not just used for reactive diagnosis
- **collaboration.yaml** - Skill dependencies, composition sequences, and integration interfaces

## Key Concepts

### Skill Structure
Skills follow a decision-tree pattern with:
- **Decision points** - Questions that branch the procedure
- **Patterns** - Reusable command sequences for common operations
- **Anti-patterns** - Things to avoid with explanations of why they're bad
- **Defaults** - Sensible default values

### Sharp Edges Philosophy
Edge cases in `sharp-edges.yaml` must be checked **before** each major phase, not after failures occur. Each edge includes:
- `detect` - How to identify the issue
- `impact` - What goes wrong if not addressed
- `fix` - How to resolve it
- `severity` - critical/high/medium

### Validation Timing
- `on_stop` validations - Must pass before procedure proceeds
- `on_warn` validations - Warnings that don't block but should be addressed

## Working with Skills

When modifying skills:
1. Keep SKILL.md and skill.yaml in sync - they describe the same procedure
2. Add new edge cases to sharp-edges.yaml when discovering failure modes
3. Add validation commands to validations.yaml for automated checking
4. Update collaboration.yaml when skill dependencies or interfaces change

When a skill is invoked:
1. Display process overview at start
2. Check prerequisites from validations.yaml
3. Follow procedure from skill.yaml, checking sharp-edges.yaml proactively at each phase
4. Use config_wizard structure for interactive configuration
5. Run post-installation validations

## Available Skills

### Core Skills
- `commit` - Git commits with conventional format
- `pr-create` - Create GitHub pull requests
- `pr-merge` - Merge pull requests with CI validation
- `bugfix` - Structured bug investigation
- `task` - Task execution and management
- `test` - Smart test runner with watch and coverage
- `tdd` - Test-driven development workflow
- `workflow` - Development workflow orchestrator
- `workflow-setup` - Initialize workflow with branch creation
- `workflow-finish` - Complete workflow with cleanup
- `linear` - Linear issue management
- `slack` - Slack integration

### Customizable Skills
- `arch` - Architecture patterns and layer boundaries
- `code` - Code style enforcement
- `developer` - Development orchestration
- `docs-refresh` - Documentation generation
- `setup` - Project setup and onboarding
- `domain-expert` - Domain knowledge and terminology
- `debugger` - Production issue debugging
- `deploy` - Deployment workflow
- `deploy-verify` - Post-deployment verification

### Meta Skills
- `framework` - Configure all skills at once
- `create-skill` - Scaffold new skills

## Security Constraints

Skills that handle secrets must follow strict masking requirements:
- Never display full API keys, passwords, or tokens
- Never execute remote commands that would expose secrets in output
- Use placeholders in generated configs, instruct users to set values manually