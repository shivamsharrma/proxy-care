---
name: plan-feature
description: Produce an implementation plan for a Proxy Care feature from its Gherkin specs using the planner subagent; saves .claude/work/<slug>/plan.md.
argument-hint: <atdd/test-specs/<feature>/[spec.feature]> | "<description>"
---

# Plan: $ARGUMENTS

1. Resolve the input to concrete `.feature` file(s). If a directory, list
   its specs and confirm which ones are in this delivery (default: all).
2. Delegate to the **planner** subagent with: the spec paths, the slug, and
   any user constraints from this conversation.
3. Check the plan before saving:
   - Every scenario in the specs appears in the Scope table.
   - Out-of-scope reasons cite the spec (open design question, other phase).
   - Each slice names files, tests, and the implementer agent.
   - Contracts mark what exists vs. new (grep to confirm).
   If something is missing, send it back to the planner once with the gaps.
4. Write `.claude/work/<slug>/plan.md` and show the user: Scope table, Open
   questions, Slices. Ask for approval or changes. Do not start tests or code.
