---
name: linear
description: Create and manage Linear issues using structured templates. Use when user says /linear.
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - AskUserQuestion
  - mcp__linear-server__create_issue
  - mcp__linear-server__update_issue
  - mcp__linear-server__get_issue
  - mcp__linear-server__list_issues
  - mcp__linear-server__list_cycles
  - mcp__linear-server__list_teams
  - mcp__linear-server__list_projects
  - mcp__linear-server__list_issue_labels
  - mcp__linear-server__list_issue_statuses
hooks:
  Stop:
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill linear"
---

# Linear

Create and manage Linear issues using structured templates.

## Overview

This skill handles Linear issue management:
- Creates issues using configurable templates (default, bug, feature)
- Converts plans/reports into properly formatted Linear issues
- Supports template mapping to projects and topics
- Supports creating issues in backlog or specific cycles

## Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| **configure** | `/linear configure` | Initial setup - discover workspace and configure templates |
| **learn** | `/linear learn` | Update cache with new workspace data |
| **template** | `/linear template <action>` | Manage issue templates |
| **create** | `/linear` | Create a new issue (default) |
| **update** | `/linear update <id>` | Update an existing issue |

## Configure Mode

Run `/linear configure` during initial setup to discover and cache your Linear workspace metadata:

```
/linear configure
```

This caches:
- **Teams** - IDs, names, keys
- **Users** - IDs, names, emails (for assignments)
- **Projects** - Per-team project list
- **Labels** - Per-team label list with colors
- **Cycles** - Cycle numbers and IDs (not "current"/"next" which are dynamic)
- **Templates** - Issue templates (default, bug, feature) with sections
- **Template Mappings** - Topic/project to template associations

During configuration, you'll be asked to:
1. **Approve or customize templates** - Use defaults or modify sections
2. **Link templates to projects/topics** - e.g., "bug" topic → Bug Report template

Cache is stored in `.claude/linear-cache.yaml` and used for faster lookups.

**When to run:**
- First time using the skill (during framework setup)
- After framework updates
- When you want to change template configuration

## Learn Mode

Run `/linear learn` to update the cache with new workspace data:

```
/linear learn
```

**When to run:**
- After team structure changes (new labels, projects, users)
- If you see "not found" errors during issue creation
- When new cycles start
- Periodically to keep cache fresh

**What it does:**
1. Fetches current workspace data from Linear API
2. Compares with existing cache
3. Reports changes (new labels, projects, etc.)
4. Updates `.claude/linear-cache.yaml`
5. Preserves templates and mappings (not overwritten)

## Template Mode

Manage issue templates with `/linear template <action>`:

| Action | Command | Description |
|--------|---------|-------------|
| **list** | `/linear template list` | Show all templates and mappings |
| **add** | `/linear template add <name>` | Create a new template |
| **edit** | `/linear template edit <name>` | Modify template sections |
| **remove** | `/linear template remove <name>` | Delete a template (except 'default') |
| **map** | `/linear template map <template> <target>` | Link template to project/topic |
| **default** | `/linear template default <name>` | Set the default template |

### Template Mapping Examples

```bash
# Map bug template to 'bug' topic
/linear template map bug topic:bug

# Map technical template to 'Backend' project
/linear template map technical project:Backend

# Set 'feature' as default template
/linear template default feature
```

## Configuration

Optional configuration (set during framework installation):

| Variable | Description |
|----------|-------------|
| `LINEAR_DEFAULT_TEAM` | Default team name (optional) |

If not configured, the skill will prompt you to select a team (or use cached teams from learn mode).

## Issue Templates

The skill includes three default templates. Templates are selected automatically based on topic/project mappings, or can be specified explicitly.

### Default Template (Standard Issue)

```markdown
## Problem Statement
[What problem are we solving and why?]

## Proposed Solution
[High-level approach]

## Acceptance Criteria
[Given/When/Then specifications]

## Implementation Plan
[Specific steps to implement]

## Technical Notes
[Implementation details, gotchas]
```

### Bug Report Template

Used automatically when topic is "bug" or label includes "Bug".

```markdown
## Bug Description
[What is the bug?]

## Steps to Reproduce
[1. Do X, 2. Do Y, 3. See error]

## Expected Behavior
[What should happen?]

## Actual Behavior
[What actually happens?]

## Environment
[OS, browser, version, etc.]
```

### Feature Request Template

Used automatically when topic is "feature" or label includes "Feature".

```markdown
## Problem Statement
[What user problem does this solve?]

## Proposed Solution
[How should this work?]

## User Stories
[As a X, I want Y, so that Z]

## Acceptance Criteria
[Definition of done]
```

### Template Selection Priority

1. **Explicit template** - User specifies: `use bug template`
2. **Project mapping** - Project linked to template in `template_mappings.projects`
3. **Topic mapping** - Label/topic linked in `template_mappings.topics`
4. **Default** - Falls back to configured default template

## Content Extraction from Plans

When given a plan/analysis/report, extract content using these mappings:

| Template Section | Extract From Document |
|-----------------|----------------------|
| **title** | Document heading, Executive Summary first sentence |
| **problem_statement** | Executive Summary, Problem, Current Pattern sections |
| **proposed_solution** | Proposed Solution, Approach, Strategy, Key Insight |
| **acceptance_criteria** | Benefits, Expected Outcomes - convert to Given/When/Then |
| **implementation_plan** | Implementation Steps - actionable steps |
| **technical_notes** | Risks and Mitigations, Gotchas, Related Files |

**Empty sections:** Omit entirely. Never use placeholder text.

## Proposal Wizard

Before creating a ticket, show a proposal for discussion:

```
## Ticket Proposal

**Title:** [inferred title]
**Template:** [template name] (matched from [reason])

### Metadata
| Field | Value | Reasoning |
|-------|-------|-----------|
| Template | Bug Report | Matched from label 'Bug' |
| Labels | Bug | [reasoning] |
| Project | [project] | [reasoning] |
| Estimate | 2pt | [file count], [complexity] |
| Cycle | next | User specified |
| State | Todo | Auto (cycle specified) |

### Description Preview
[First lines of each section...]

---
**Ready to create?** Or adjust any options?
(You can also change the template with "use [template] template")
```

Wait for user approval before creating.

## Metadata Inference

| Field | Inference | How |
|-------|-----------|-----|
| **labels** | Auto | Infer from work type |
| **project** | Auto | Infer from affected area |
| **estimate** | Auto | Based on effort calculation |
| **priority** | Ask | Only infer if "critical"/"blocking" language |
| **cycle** | User | Use what user says, default backlog |
| **state** | Auto | Todo if cycle specified, else Backlog |
| **assignee** | Ask | Ask or leave unassigned |

## Estimate Guide

| Points | Time | Scope |
|--------|------|-------|
| 1pt | ~4 hours | 1-3 files, simple, 1 iteration |
| 2pt | ~1 workday | 1-5 files, moderate, 2 iterations |
| 3pt | ~2 workdays | 5-10 files, some complexity |
| 5pt | ~2-4 workdays | 10-20 files, significant refactoring |
| 8pt | ~1 workweek | 20+ files, architectural, critical path |

## Quick Reference

### Creates
- Linear issues in configured team with proper template formatting

### Required Fields (depends on template)

**Default template:**
- **title** - Issue title
- **problem_statement** - What problem are we solving?

**Bug template:**
- **title** - Issue title
- **description** - Bug description
- **steps_to_reproduce** - Steps to reproduce
- **expected_behavior** - What should happen
- **actual_behavior** - What actually happens

**Feature template:**
- **title** - Issue title
- **problem_statement** - What user problem does this solve?
- **proposed_solution** - How should this work?

### Optional Metadata
| Field | Description | Example |
|-------|-------------|---------|
| template | Template to use | "default", "bug", "feature" |
| assignee | Who will work on it | "me", "name" |
| labels | Issue labels | ["Bug", "Improvement"] |
| project | Project name | "Project Name" |
| cycle | Sprint cycle | "current", "next", 26 |
| priority | 1=Urgent, 2=High, 3=Normal, 4=Low | 2 |
| estimate | Story points | 3 |

### Optional Relationships
| Field | Description | Example |
|-------|-------------|---------|
| parent_id | Create as sub-issue | "XXX-123" |
| blocks | Issues this blocks | ["XXX-456"] |
| blocked_by | Issues blocking this | ["XXX-100"] |
| related_to | Related issues | ["XXX-310"] |

## Usage

1. Request required information if not provided
2. Format content using the template
3. Show proposal wizard for user approval
4. Create issue in Linear with appropriate metadata

## Full Documentation

See `skill.yaml` for complete procedure, patterns, and template details.
