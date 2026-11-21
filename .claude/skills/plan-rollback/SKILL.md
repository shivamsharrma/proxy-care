---
name: plan-rollback
description: "Plan a rollback for a bad PR, commit or release: a revert PR on a branch plus a runbook for a human to execute, covering Flyway migrations, API and ErrorCode compatibility and payments. Plans only — never deploys, merges or runs cloud commands."
argument-hint: <pr-number | commit | environment>
disable-model-invocation: true
---

# Plan rollback: $ARGUMENTS

1. Delegate to **release-manager** to identify: the offending PR/commits,
   the last known-good commit/image tag (`/report-release-status`), and what changed
   (`git show --stat`).
2. Assess compatibility before proposing anything:
   - **DB migrations** — was a Flyway migration applied
     (`flyway_schema_history`)? Migrations are forward-only: the old code
     must still start over the newer schema (`ddl-auto: validate` fails on a
     missing or retyped column). Never propose deleting a migration or
     dropping columns/data; if needed, a forward-fix `V<n+1>__` migration.
   - **Error codes / API** — a revert must not remove or rename an
     `ErrorCode` or response field that released apps already read.
   - **Payments** — in-flight Razorpay orders/webhooks must still be handled.
   - **Client** — mobile builds can't be recalled; server must stay
     backward-compatible with released app versions.
3. Prepare (with user approval): branch `fix/revert-<ref>`, `git revert
   <commits>` (no history rewrite), run `/run-quality-gate`, then `/open-pr`.
4. Write `.claude/work/rollback-<ref>/runbook.md`: exact human steps to
   redeploy the known-good version, checks to confirm recovery, and who to tell.
