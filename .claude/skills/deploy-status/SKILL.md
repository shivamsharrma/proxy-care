---
name: deploy-status
description: Read-only status report for a PR, branch or environment — GitHub Actions checks, latest workflow runs, and AWS service health via read-only MCP.
argument-hint: [pr-number | branch | environment]
---

# Deploy status: $ARGUMENTS

Delegate to **release-manager** (read-only commands only):

1. **CI** — `gh pr checks <pr>` or `gh run list --branch <branch> --limit 5`;
   for failures, `gh run view <id> --log-failed` (first relevant lines).
2. **Workflows** — `ci.yml`, `goldens.yml`, `pages.yml` latest runs on `main`.
3. **AWS** (if the `aws` MCP server is connected and an environment was
   given) — service/task status, last deployment time and image tag, recent
   error-level logs, alarms in ALARM. Read-only operations only. See the
   `aws-deploy` skill for what to look at.
4. **Supabase** (if connected) — pending vs applied migrations, advisors.

Output a short table: component | state | since | link. Flag anything red
with the next diagnostic step. Never trigger re-runs or deployments.
