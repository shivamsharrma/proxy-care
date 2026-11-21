---
name: write-failing-tests
description: "Pipeline stage 2: write the failing tests for one planned slice — Flutter unit/widget, Maestro flows, backend unit/integration — via test-writer, and confirm each fails for the right reason. Writes no production code."
argument-hint: <slug> [slice-number]
---

# Write failing tests: $ARGUMENTS

1. Slug: argument, else from branch `feat/<slug>`. Read
   `.claude/work/<slug>/plan.md`; pick the given slice, else the first
   without tests. No plan → run `/plan-feature` first.
2. Delegate to **test-writer** with: slice text, scenario names and spec
   paths, test file paths from the plan.
3. Check the result yourself:
   - Run the new tests (`testing.md` → Commands → Run specific
     tests). They fail for the right reason (`testing.md` → Rules).
   - Maestro flows exist at the planned paths with the header from
     `testing.md` → Maestro mapping (`maestro check-syntax <file>` if
     installed, else NOT RUN).
   - No production files changed (`git diff --name-only` shows only
     `proxy-care-client/test/`, `proxy-care-client/maestro/`,
     `proxy-care-backend/src/test/`).
4. Append to `.claude/work/<slug>/status.md`: tests written, scenario → test
   mapping, failure summary.
