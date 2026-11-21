---
name: aws-deploy
description: Read-only AWS checks and pre-deploy/post-deploy checklists for the Proxy Care backend — service health, logs, alarms, secrets presence, and human-run deploy runbooks. Use when asked about deployments, environments or production health.
---

# AWS deploy

Claude's AWS access is **read-only** (the `aws` MCP server runs with
`READ_OPERATIONS_ONLY=true`). Deploys run through CI/CD with human approval;
there is no deploy workflow in `.github/workflows/` yet — when one is added,
document it here.

## Pre-deploy checklist (report each item)
- [ ] PR merged with green CI; image/artifact tag = merge commit SHA.
- [ ] Migrations: backward-compatible with the currently running version
      (expand → deploy → contract); applied before the app deploy.
- [ ] Kafka: new topics exist; event version changes dual-published.
- [ ] Secrets referenced by the new config exist in Secrets Manager / SSM
      (check names only — never read values).
- [ ] Razorpay/Uber webhook URLs unchanged or updated with the provider.
- [ ] Rollback target identified (previous tag) — see `/rollback`.

## Health checks (read-only)
- Service: desired vs running tasks, last deployment status and time,
  running image tag.
- Load balancer target health; 5xx rate and p95 latency (CloudWatch).
- Logs: error-level entries since deploy (CloudWatch Logs Insights).
- Alarms currently in ALARM.
- Kafka (MSK): consumer lag per group, DLT message counts.

## Never
Run `update-service`, `deploy`, `put-*`, `delete-*`, `scale`, or read secret
values. Write the exact command into a runbook for a human instead.
