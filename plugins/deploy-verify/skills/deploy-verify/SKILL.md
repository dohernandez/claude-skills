---
name: deploy-verify
description: "Verify deployment status, health, and startup. Use when user says /deploy-verify or asks to check deployment."
user-invocable: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
hooks:
  Stop:
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill deploy-verify"
---

# Deploy Verify

## Purpose

Verify that services deployed correctly after a deployment. Provides a systematic checklist to confirm service health, successful startup, and proper operation.

## When to Use

- After running a deployment workflow
- Checking if services are healthy
- Investigating deployment failures
- Verifying rollback success

## Quick Reference

- **Setup**: `/deploy-verify configure` (run once during framework setup)
- **Usage**: `/deploy-verify` (uses saved config)
- **Update**: `/deploy-verify learn` (re-analyze deployment setup)
- **Config**: `.claude/skills/deploy-verify.yaml`

## Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/deploy-verify configure` | Auto-detect deployment platform and services | Framework setup / wizard |
| `/deploy-verify learn` | Update config from current deployment setup | After infrastructure changes |
| `/deploy-verify` | Run verification against saved config | Normal usage |

---

## /deploy-verify configure

**When**: Framework setup wizard (one-time)

**What it does**:
1. Detects deployment platform (Kubernetes, Cloud Run, Docker, etc.)
2. Identifies services and their health endpoints
3. Discovers CI/CD workflow configuration
4. Proposes verification configuration to user
5. Saves to `.claude/skills/deploy-verify.yaml`

### Discovery Process

```
1. DETECT PLATFORM
   ├─ Kubernetes: k8s/, kubernetes/, helm/
   ├─ Cloud Run: deploy with gcloud run
   ├─ Docker Compose: docker-compose.yaml
   ├─ AWS ECS: ecs/, task-definition.json
   ├─ Serverless: serverless.yaml
   └─ Custom: Makefile, Taskfile.yaml targets

2. IDENTIFY SERVICES
   ├─ Scan deployment configs for service names
   ├─ Find health check endpoints
   └─ Detect environment variables

3. DISCOVER CI/CD
   ├─ GitHub Actions: .github/workflows/deploy*.yaml
   ├─ GitLab CI: .gitlab-ci.yml
   ├─ CircleCI: .circleci/config.yml
   └─ Custom: Taskfile.yaml, Makefile

4. PROPOSE TO USER
   └─ Show discovered config, wait for approval
```

### Proposal Format

```yaml
# Proposed Deploy Verify Configuration
# Review and approve to save to .claude/skills/deploy-verify.yaml

platform:
  type: kubernetes  # kubernetes | cloud-run | docker-compose | ecs | custom
  project: my-project
  region: us-central1

services:
  - name: api
    health_endpoint: /health
    expected_status: 200
    startup_log: "Server started"
  - name: worker
    health_endpoint: /healthz
    expected_status: 200
    startup_log: "Worker ready"

ci_cd:
  workflow: .github/workflows/deploy.yaml
  check_command: "gh run list --workflow=deploy.yaml --limit=1"

verification:
  commands:
    list_services: "kubectl get deployments -n production"
    check_health: "curl -f {health_endpoint}"
    check_logs: "kubectl logs -l app={service} --since=10m"

  checks:
    - name: deployment_status
      command: "kubectl rollout status deployment/{service}"
    - name: pod_health
      command: "kubectl get pods -l app={service} -o jsonpath='{.items[*].status.phase}'"
```

### Save Location

```
.claude/skills/deploy-verify.yaml
```

---

## /deploy-verify learn

**When**: Infrastructure or deployment setup changed

**What it does**:
1. Re-scans deployment configuration
2. Updates service list and health endpoints
3. Proposes config updates to user
4. Updates `.claude/skills/deploy-verify.yaml`

---

## /deploy-verify (Normal Usage)

**When**: After deployment, to verify success

**Requires**: `.claude/skills/deploy-verify.yaml` exists

### Verification Workflow

```
1. CHECK CI/CD STATUS
   └─ Verify deployment workflow completed successfully

2. LIST SERVICES
   └─ Confirm expected services are deployed

3. CHECK SERVICE STATUS
   └─ Verify services report ready/healthy

4. CHECK FOR ERRORS
   └─ Query recent logs for errors

5. VERIFY STARTUP LOGS
   └─ Confirm expected startup messages present

6. RUN HEALTH CHECKS
   └─ Hit health endpoints, verify responses

7. GENERATE REPORT
   └─ Compile results into summary
```

---

## Verification Levels

| Level | Question | Checks |
|-------|----------|--------|
| **Process** | Did deployment complete? | CI/CD workflow status, exit code |
| **Service** | Are services running? | Service status, ready conditions |
| **Startup** | Did services start cleanly? | Startup logs, no critical errors |
| **Health** | Are services responding? | Health endpoints, basic operations |

---

## Report Format

```
## Deployment Verification Report

**Environment:** production
**Deployment Time:** 2026-01-25T13:25Z
**Workflow:** deploy.yaml #144 - Success

### Service Status
| Service | Status | Health | Errors |
|---------|--------|--------|--------|
| api | Running | 200 OK | None |
| worker | Running | 200 OK | None |

### Startup Verification
| Service | Expected Log | Found |
|---------|--------------|-------|
| api | "Server started" | Yes |
| worker | "Worker ready" | Yes |

### Overall: PASSED
```

---

## Platform Examples

### Kubernetes

```yaml
# .claude/skills/deploy-verify.yaml
platform:
  type: kubernetes
  namespace: production

verification:
  commands:
    list_services: "kubectl get deployments -n {namespace}"
    check_status: "kubectl rollout status deployment/{service} -n {namespace}"
    check_logs: "kubectl logs -l app={service} -n {namespace} --since=10m | grep -i error"
    check_health: "kubectl exec deploy/{service} -- curl -f localhost:{port}/health"
```

### Docker Compose

```yaml
# .claude/skills/deploy-verify.yaml
platform:
  type: docker-compose
  compose_file: docker-compose.yaml

verification:
  commands:
    list_services: "docker compose ps"
    check_status: "docker compose ps {service} --format json"
    check_logs: "docker compose logs {service} --since 10m | grep -i error"
    check_health: "curl -f http://localhost:{port}/health"
```

### Cloud Run (GCP)

```yaml
# .claude/skills/deploy-verify.yaml
platform:
  type: cloud-run
  project: my-project
  region: us-central1

verification:
  commands:
    list_services: "gcloud run services list --region={region} --project={project}"
    check_status: "gcloud run services describe {service} --region={region} --format='yaml(status.conditions)'"
    check_logs: "gcloud logging read 'resource.labels.service_name=\"{service}\" AND severity>=ERROR' --limit=20"
```

### Custom (Taskfile)

```yaml
# .claude/skills/deploy-verify.yaml
platform:
  type: custom

verification:
  commands:
    check_status: "task deploy:status"
    check_health: "task deploy:health"
    check_logs: "task deploy:logs -- --errors"
```

---

## Common Issues

| Issue | Symptom | Resolution |
|-------|---------|------------|
| Service not ready | Status shows pending/not ready | Check container logs for startup errors |
| Health check fails | Endpoint returns non-200 | Check service logs, verify port binding |
| No startup logs | Missing expected messages | Container may have crashed on startup |
| Deployment timeout | Workflow stuck or failed | Check resource limits, image pull issues |
| Config mismatch | Service behaves unexpectedly | Verify environment variables deployed |

---

## Automation

See `skill.yaml` for patterns and procedures.
See `sharp-edges.yaml` for common deployment verification pitfalls.
