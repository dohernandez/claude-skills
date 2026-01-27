---
name: debugger
description: Debug production service issues via alerts and logs. Use when user says /debugger or /debug.
user-invocable: true
allowed-tools: [Read, Bash, WebFetch]
---

# Debugger

## Purpose

Guide systematic debugging of production service issues by analyzing alerts and logs to identify root causes.

## When to Use

- Production alerts requiring investigation
- Service errors or unexpected behavior
- Debugging incidents and outages
- Recurring error pattern analysis

## Quick Reference

- **Setup**: `/debugger configure` (run once during framework setup)
- **Usage**: `/debugger` or `/debug` (uses saved config)
- **Update**: `/debugger learn <path>` (analyze specific service)
- **Config**: `.claude/skills/debugger.yaml`

## Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| **configure** | `/debugger configure` | Auto-detect log commands, alert sources, services |
| **learn** | `/debugger learn <path>` | Learn patterns from specific service or logs |
| **debug** | `/debugger` | Debug an alert or error (default) |

## Workflow Phases

1. **Prerequisites Check**: Verify log access, authentication, alert source access
2. **Alert Triage**: Parse alert, identify type and affected service
3. **Service Identification**: Map alert keywords to services
4. **Log Analysis**: Query logs, filter by time and severity
5. **Root Cause Hypothesis**: Analyze patterns, suggest fixes
6. **Next Steps**: Recommend fix or further investigation

## Configuration

### Config Location

Config path depends on how the plugin was installed:

| Plugin Scope | Config File | Git |
|--------------|-------------|-----|
| **project** | `.claude/skills/debugger.yaml` | Committed (shared) |
| **local** | `.claude/skills/debugger.local.yaml` | Ignored (personal) |
| **user** | `.claude/skills/debugger.local.yaml` | Ignored (personal) |

**Precedence when reading** (first found wins):
1. `.claude/skills/debugger.local.yaml`
2. `.claude/skills/debugger.yaml`
3. Skill defaults

### Config Fields

Configured via wizard during `/debugger configure`:

| Variable | Description | Example |
|----------|-------------|---------|
| `LOG_COMMAND` | Command to view logs | `kubectl logs`, `docker logs`, `gcloud logging read` |
| `DEBUG_ENV` | How to enable debug mode | `DEBUG=true`, `LOG_LEVEL=debug` |

## Automation

See `skill.yaml` for error categories and log query patterns.
See `sharp-edges.yaml` for common debugging pitfalls.
See `collaboration.yaml` for related skills.
