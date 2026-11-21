---
name: implement-slice
description: "Pipeline stage 3: make one planned slice's failing tests pass by delegating to client-implementer or backend-implementer per plan.md, then check the slice's tests and gate. Use after /write-failing-tests, or to address review or gate findings."
argument-hint: <slug> [slice-number]
---

# Implement slice: $ARGUMENTS

1. Read `.claude/work/<slug>/plan.md` and `status.md`; pick the given slice,
   else the first whose tests are written but not passing.
2. Delegate by the slice's implementer:
   - client → **client-implementer**; backend → **backend-implementer**;
   - both → backend first, then client with the backend's contract handoff
     in the prompt.

   Prompt: slice text, test paths, the domain skill, and any review or gate
   findings being addressed.
3. Check the result yourself (commands: `testing.md` → Commands):
   - `git diff --name-only`: no test file changed unless the user approved.
   - "Run specific tests" passes for the slice.
   - Client slice: "Layer rules" passes. Backend slice: backend "Full gate" passes.
4. Update `status.md`. If the implementer reported a wrong test or a missing
   decision, stop and ask the user.
