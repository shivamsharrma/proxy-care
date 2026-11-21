---
name: verify
description: Run the full local quality gate via the verifier subagent (codegen freshness, format, analyze, tests, architecture, server build, optional Maestro E2E) and record the verdict.
argument-hint: [slug] [--e2e]
---

# Verify: $ARGUMENTS

1. Determine slug (argument or branch name). Read `plan.md` for in-scope
   scenarios and Maestro flow paths.
2. Delegate to **verifier** with: slug, scenario list, flow paths, and
   whether E2E was requested (`--e2e`).
3. Save its report to `.claude/work/<slug>/verify.md`.
4. Show the table and verdict. `VERDICT: PASS` is required for `/open-pr`.
   Report NOT RUN checks plainly — never upgrade them to PASS.
