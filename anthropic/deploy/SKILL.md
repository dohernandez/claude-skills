---
name: deploy
description: "Deploy services to target environments. Handles environment selection, deployment locking, and workflow triggering. Use when user says /deploy."
user-invocable: true
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
hooks:
  Stop:
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill deploy"
---

# Deploy

## Purpose

Deploy services to target environments via CI/CD workflow. Handles environment selection, deployment locking to prevent concurrent deploys, and triggers deployment with appropriate options.

## When to Use

- Deploying changes to staging or production
- Releasing new features after PR merge
- Hotfix deployments
- Rollback to previous version

## Quick Reference

- **Setup**: `/deploy discover` (run once during framework setup)
- **Usage**: `/deploy` (uses saved config)
- **Update**: `/deploy learn` (re-analyze deployment setup)
- **Config**: `.claude/skills/deploy.yaml`

## Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| **discover** | `/deploy discover` | Auto-detect deployment commands, environments |
| **learn** | `/deploy learn` | Update config from recent deployments |
| **deploy** | `/deploy` | Deploy to environment (default) |

## Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. SELECT ENV  →  2. CHECK LOCK  →  3. DEPLOY  →  4. VERIFY        │
└─────────────────────────────────────────────────────────────────────┘
```

## Step 1: Select Environment

Ask the user which environment to deploy to (configured via discover).

## Step 2: Check Deployment Lock

Before deploying, check if another deployment is in progress:

```bash
# Example: GitHub Actions
gh run list --workflow=deploy.yaml --status=in_progress --json databaseId,status

# Example: Check for queued
gh run list --workflow=deploy.yaml --status=queued --json databaseId,status
```

**Lock Rules:**
- If deployment is `in_progress` → STOP, wait for completion
- If deployment is `queued` → STOP, wait or cancel
- If no active deployments → PROCEED

## Step 3: Trigger Deployment

Use the configured DEPLOY_COMMAND from `.claude/skills/deploy.yaml`:

```bash
# Examples based on platform:
# GitHub Actions
gh workflow run deploy.yaml -f environment=staging

# Kubernetes
kubectl apply -f k8s/staging/

# Task runner
task deploy:staging

# npm script
npm run deploy -- --env staging
```

## Step 4: Monitor and Verify

```bash
# Watch workflow (GitHub Actions)
gh run watch

# Check status
gh run list --workflow=deploy.yaml --limit=1

# After completion, verify deployment
# (Use deploy-verify skill)
```

## Configuration

Configured via wizard during framework installation:

| Variable | Description | Example |
|----------|-------------|---------|
| `DEPLOY_COMMAND` | Command to deploy | `gh workflow run deploy.yaml` |
| `ENVIRONMENTS` | Available environments | `staging,production` |
| `DEPLOY_BRANCH` | Branch for production | `main` |

## Deployment Scenarios

### Standard Deployment (Most Common)

```bash
# Using configured command
${DEPLOY_COMMAND} -f environment=staging
```

### Force Rebuild

When you need to rebuild (e.g., dependency updates):

```bash
${DEPLOY_COMMAND} -f environment=staging -f force_build=true
```

### Deploy Specific Version

Rollback or deploy specific commit:

```bash
${DEPLOY_COMMAND} -f environment=staging -f version=<commit-sha>
```

## Lock Management

### Check Lock Status

```bash
# GitHub Actions example
IN_PROGRESS=$(gh run list --workflow=deploy.yaml --status=in_progress --json databaseId | jq length)
QUEUED=$(gh run list --workflow=deploy.yaml --status=queued --json databaseId | jq length)

if [ "$IN_PROGRESS" -gt 0 ] || [ "$QUEUED" -gt 0 ]; then
  echo "Deployment locked: $IN_PROGRESS in progress, $QUEUED queued"
else
  echo "No active deployments - safe to deploy"
fi
```

### Cancel Stuck Deployment

If a deployment is stuck (use with caution):

```bash
# Get the run ID
gh run list --workflow=deploy.yaml --status=in_progress --json databaseId

# Cancel the run
gh run cancel <run-id>
```

## Post-Deployment

After deployment completes:

1. **Verify with deploy-verify skill**: `/deploy-verify`
2. **Check service health**
3. **Monitor logs for errors**

## Automation

See `skill.yaml` for the full deployment procedure.
See `sharp-edges.yaml` for common deployment pitfalls.

## Related Skills

| Skill | Relationship |
|-------|--------------|
| `deploy-verify` | Verify deployment success after this skill runs |
| `debugger` | Debug if deployment has issues |
