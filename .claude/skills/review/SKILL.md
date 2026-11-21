---
name: review
description: Run the four read-only reviewers (correctness, security, architecture, tests) in parallel on the current branch's diff and consolidate findings into .claude/work/<slug>/review.md.
argument-hint: [slug] [base-ref=main]
---

# Review: $ARGUMENTS

1. Determine slug (from argument or current branch `feat/<slug>`) and base
   (default `main`).
2. Write the diff for the read-only reviewers:
   `git diff <base>...HEAD -- . ':(exclude)*.g.dart' ':(exclude)*.freezed.dart' ':(exclude)**/l10n/generated/**' > .claude/work/<slug>/review.diff`
   plus uncommitted changes (`git diff HEAD` appended) if any.
3. In **one message**, launch all four subagents in parallel:
   **reviewer-correctness**, **reviewer-security**, **reviewer-architecture**,
   **reviewer-tests**. Each prompt: diff path, plan path, spec paths.
4. Consolidate into `.claude/work/<slug>/review.md`:
   - Deduplicate overlapping findings; keep the highest severity.
   - Drop findings that don't point at a real line (verify by reading it).
   - Sections: BLOCKER, MAJOR, MINOR, then the tests reviewer's traceability table.
5. Show the user the BLOCKER/MAJOR list. Verdict: `CHANGES REQUIRED` if any
   BLOCKER/MAJOR, else `APPROVED (with N minors)`.

Reviewers never edit. Fixes go through `/implement` with the findings.
