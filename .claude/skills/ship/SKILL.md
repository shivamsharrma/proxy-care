---
name: ship
description: End-to-end delivery pipeline for one Proxy Care feature or spec — plan, failing tests, implement, parallel review, verify, open PR — orchestrated from the main thread with human approval gates.
argument-hint: <atdd/test-specs/<feature>/[spec.feature]> | "<feature description>"
disable-model-invocation: true
---

# /ship $ARGUMENTS

You are the orchestrator. Subagents cannot spawn subagents, so **you** run
every stage from the main thread and pass artifacts between them. Each stage
is defined in its own skill file; follow it exactly.

## 0. Setup
- Derive `<slug>` from the argument: `<feature-dir>-<spec-stem>` (e.g.
  `pickup-and-ride-05-caretaker-ride-payment`) or a kebab-case summary.
- Work dir: `.claude/work/<slug>/` (gitignored). Create it.
- If on `main`, create `feat/<slug>` (`git switch -c`). Never work on `main`.
- Keep a checklist in `.claude/work/<slug>/status.md`, updated after each stage.

## 1. Plan — `.claude/skills/plan-feature/SKILL.md`
Save to `plan.md`. **GATE 1:** show the user the Scope table, Open questions
and Slices; wait for explicit approval. If the plan says `BLOCKED`, stop.

## Per slice (in plan order)

### 2. Failing tests — `.claude/skills/write-tests/SKILL.md`
Must end with tests failing for the right reason.

### 3. Implement — `.claude/skills/implement/SKILL.md`
Must end green for the slice's tests.

### 4. Review — `.claude/skills/review/SKILL.md`
Four reviewers in parallel. Fix every BLOCKER and MAJOR by sending the
implementer back with the findings (max 2 rounds; then stop and ask the
user). MINORs: fix if cheap, else list in the PR.

### 5. Verify — `.claude/skills/verify/SKILL.md`
Requires `VERDICT: PASS`. On FAIL: send failures to the implementer, then
re-verify (max 2 rounds, then stop and ask).

### Commit
One commit per slice on the feature branch (`git-and-pr.md` style). Never
`--no-verify`.

## 6. Open PR — `.claude/skills/open-pr/SKILL.md`
**GATE 2:** show the PR title/body and the verify table; push and open the
PR only after the user approves. Never merge.

## Rules
- Stop and ask whenever: a spec is ambiguous, a test must change to pass, a
  new dependency or migration on a shared DB is needed, or a stage fails twice.
- Report honestly: stages skipped or NOT RUN (e.g. Maestro without a device)
  are stated as such in `status.md` and the PR.
- End with a summary: PR URL, scenarios covered, anything deferred.
