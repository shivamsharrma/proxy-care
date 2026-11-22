---
name: run-quality-gate
description: "Pipeline stage 5: run the full local quality gate via quality-gate-runner — codegen freshness, format, analyze, tests, layer rules, backend build, optional Maestro E2E (--e2e) — and record the PASS/FAIL verdict in .claude/work/<slug>/verify.md. Use before committing a slice and before /open-pr."
argument-hint: "[slug] [--e2e]"
---

# Run quality gate: $ARGUMENTS

1. Slug: argument, else from branch `feat/<slug>`. Read `plan.md` for the
   in-scope scenarios and Maestro flow paths.
2. Delegate to **quality-gate-runner** with: slug, scenario list, flow paths,
   and whether E2E was requested (`--e2e`).
3. Save its report verbatim to `.claude/work/<slug>/verify.md` (overwrite).
4. Show the user the table and verdict.
