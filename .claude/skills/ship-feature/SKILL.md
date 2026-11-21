---
name: ship-feature
description: "Deliver one Proxy Care feature or spec end to end — /plan-feature, then per slice /write-failing-tests, /implement-slice, /review-changes, /run-quality-gate and a commit, then /open-pr — from the main thread, stopping at the human approval gates."
argument-hint: '<atdd/test-specs/<feature>/[spec.feature]> | "<feature description>"'
disable-model-invocation: true
---

# /ship-feature $ARGUMENTS

You orchestrate from the main thread (subagents cannot spawn subagents) and
pass artifacts between stages. Each stage is its own skill; follow it exactly.

## Setup
- Slug and branch per `CLAUDE.md` → Delivery workflow. On `main`:
  `git switch -c feat/<slug>`.
- Create `.claude/work/<slug>/status.md`: one checklist line per stage and
  slice, updated after each stage.

## Stages
1. `/plan-feature` — **GATE 1** is its approval step. `BLOCKED` plan → stop.
2. Per slice, in plan order:
   1. `/write-failing-tests` — ends with tests failing for the right reason.
   2. `/implement-slice` — ends green for the slice's tests.
   3. `/review-changes` — every BLOCKER/MAJOR goes back through
      `/implement-slice` with the findings. MINORs: fix if cheap, else carry
      them to the PR body.
   4. `/run-quality-gate` — needs `VERDICT: PASS`; failures go back through
      `/implement-slice`.
   5. Commit the slice (`git-and-pr.md` → Commits). If `git status --porcelain`
      is then empty, append `Verified commit: <git rev-parse HEAD>` to
      `verify.md` — the gate ran on exactly this tree.
3. `/open-pr` — **GATE 2** is its approval step.

Review and gate loops get 2 rounds each; on a third failure stop and ask.
Every other stop condition is in `CLAUDE.md` → Always.

## Finish
Summary: PR URL, scenarios covered, anything deferred or NOT RUN (also
recorded in `status.md` and the PR body).
