---
name: report-release-status
description: "Read-only status report for a PR, branch or environment: GitHub Actions checks (ci.yml, backend.yml), latest workflow runs, and applied Flyway migrations versus the migration files. Use to answer \"is it green / is it deployed\". Changes nothing."
argument-hint: "[pr-number | branch | environment]"
---

# Release status: $ARGUMENTS

Delegate to **release-manager** (read-only commands only):

1. **CI** — `gh pr checks <pr>` or `gh run list --branch <branch> --limit 5`;
   for failures, `gh run view <id> --log-failed` (first relevant lines).
2. **Workflows** — `backend.yml`, `ci.yml`, `goldens.yml`, `pages.yml` latest
   runs on `main` (and on the given branch).
3. **Supabase** (if connected, read-only) — applied Flyway versions
   (`select version, success from flyway_schema_history order by installed_rank`)
   vs files in `proxy-care-backend/src/main/resources/db/migration/`, and advisors.

Output a short table: component | state | since | link. Flag anything red
with the next diagnostic step. Never trigger re-runs or deployments.
