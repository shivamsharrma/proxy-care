---
name: implement
description: Implement a planned slice until its failing tests pass, routing to flutter-implementer or spring-implementer per the plan.
argument-hint: <slug> [slice-number]
---

# Implement: $ARGUMENTS

1. Read `.claude/work/<slug>/plan.md` and `status.md`; pick the slice whose
   tests are written but not passing.
2. Delegate by the slice's implementer field:
   - client → **flutter-implementer**
   - server → **spring-implementer**
   - both → server first (contract), then client; pass the server's
     contract report into the client prompt.
   Include: slice text, test paths, relevant rules and domain skill name,
   and any review/verify findings being addressed.
3. Check the result yourself:
   - `git diff --name-only` — test files unchanged (unless the user approved).
   - Re-run the slice's tests; they pass.
   - `cd proxy-care-client && flutter test test/architecture` passes.
4. Update `status.md`. If the implementer reported a wrong test or missing
   decision, stop and ask the user.
