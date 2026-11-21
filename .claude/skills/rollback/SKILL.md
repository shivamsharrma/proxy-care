---
name: rollback
description: Plan a rollback for a bad change — revert PR on a branch plus a human-executed redeploy runbook covering migrations and Kafka compatibility. Never deploys or merges.
argument-hint: <pr-number | commit | environment>
disable-model-invocation: true
---

# Rollback: $ARGUMENTS

1. Delegate to **release-manager** to identify: the offending PR/commits,
   the last known-good commit/image tag (`/deploy-status`), and what changed
   (`git show --stat`).
2. Assess compatibility before proposing anything:
   - **DB migrations** — was a migration applied? Reverting code over a
     newer schema must still work; never propose dropping columns/data.
     If needed, a forward-fix migration instead.
   - **Kafka** — new topics/event versions consumed elsewhere? Producers
     rolled back must not strand consumers; keep dual-publish if one existed.
   - **Payments** — in-flight Razorpay orders/webhooks must still be handled.
   - **Client** — mobile builds can't be recalled; server must stay
     backward-compatible with released app versions.
3. Prepare (with user approval): branch `fix/revert-<ref>`, `git revert
   <commits>` (no history rewrite), run `/verify`, then `/open-pr`.
4. Write `.claude/work/rollback-<ref>/runbook.md`: exact human steps to
   redeploy the known-good version, checks to confirm recovery, and who to tell.
5. Never run mutating AWS/Supabase commands, force-push, or merge.
