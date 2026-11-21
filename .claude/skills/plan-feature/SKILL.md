---
name: plan-feature
description: "Pipeline stage 1: turn a feature's Gherkin specs (or a description) into an implementation plan — scope per scenario, slices, contracts, open questions — via feature-planner, saved to .claude/work/<slug>/plan.md for user approval. Writes no tests or code."
argument-hint: '<atdd/test-specs/<feature>/[spec.feature]> | "<description>"'
---

# Plan feature: $ARGUMENTS

1. Resolve the input to concrete `.feature` file(s). If a directory, list
   its specs and confirm which ones are in this delivery (default: all).
   Derive the slug per `CLAUDE.md` → Delivery workflow.
2. Delegate to **feature-planner** with: the spec paths, the slug, and any
   user constraints from this conversation.
3. Check the plan before saving:
   - Every scenario in the specs appears in the Scope table.
   - Out-of-scope reasons cite the spec (open design question, other phase).
   - Each slice names files, tests, and the implementer agent.
   - Contracts mark what exists vs. new (grep to confirm).
   If something is missing, send it back to feature-planner once with the gaps.
4. Write `.claude/work/<slug>/plan.md`. **GATE 1:** show the user the Scope
   table, Open questions and Slices; wait for explicit approval or changes.
   Do not start tests or code.
