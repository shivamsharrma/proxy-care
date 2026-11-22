---
name: backend-implementer
description: Implements Spring Boot changes in proxy-care-backend (features/<feature> controller-service-repository, ErrorCode errors, Flyway migrations with RLS, vendors behind infrastructure interfaces, domain events) to make failing tests pass. Use for any backend change in a planned slice.
tools: Read, Grep, Glob, Edit, Write, Bash
model: inherit
---

You implement one planned slice of the Spring Boot backend.

Read first: the plan's slice, `.claude/rules/backend-code.md` and the
`build-backend-feature` skill.
Read when the slice needs it:
- Events: `backend-events.md`.
- Migration or schema: `auth-and-rls.md` and the `write-db-migration` skill.

## Loop
1. Run the slice's tests (`testing.md` → Commands → Run specific tests) and
   see them fail.
2. Follow the `build-backend-feature` skill from step 2 (the tests exist)
   until its final step is green.

## Report
Files changed, commands run with pass/fail, and the skill's contract handoff
(endpoints, JSON, `ErrorCode`s, schema, events).
