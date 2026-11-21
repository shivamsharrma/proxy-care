---
name: write-tests
description: Write failing tests (Flutter unit/widget, Maestro flows, server tests) for a planned slice using the test-writer subagent, and confirm they fail for the right reason.
argument-hint: <slug> [slice-number]
---

# Write tests: $ARGUMENTS

1. Read `.claude/work/<slug>/plan.md`; pick the slice (default: first
   without tests). No plan → run `/plan-feature` first.
2. Delegate to **test-writer** with: slice text, scenario names and spec
   paths, test file paths from the plan.
3. Check the result yourself:
   - Run the new client tests: `cd proxy-care-client && flutter test <paths>`.
     They must fail on missing behaviour/types the plan names, not on typos
     or broken imports of existing code.
   - Maestro flows exist at the planned paths with spec comment + tags
     (validate syntax with `maestro check-syntax <file>` if maestro is installed).
   - No production files changed (`git diff --name-only` shows only `test/`,
     `maestro/`, `src/test/`, `supabase/tests/`).
4. Append to `.claude/work/<slug>/status.md`: tests written, scenario → test
   mapping, failure summary.
