---
name: review-changes
description: "Pipeline stage 4: run the four read-only reviewers (correctness, security, architecture, tests) in parallel on the branch diff and consolidate their findings by severity into .claude/work/<slug>/review.md. Use after /implement-slice; BLOCKER/MAJOR findings go back to implementation."
argument-hint: "[slug] [base-ref=main]"
---

# Review changes: $ARGUMENTS

1. Slug: argument, else from branch `feat/<slug>`. Base: argument, else `main`.
2. Write the diff for the reviewers:
   `git diff <base>...HEAD -- . ':(exclude)*.g.dart' ':(exclude)*.freezed.dart' ':(exclude)**/l10n/generated/**' > .claude/work/<slug>/review.diff`,
   then append `git diff HEAD` (same excludes) if there are uncommitted changes.
3. In **one message**, launch **reviewer-correctness**, **reviewer-security**,
   **reviewer-architecture** and **reviewer-tests** in parallel. Each prompt:
   diff path, plan path, spec paths, and the Findings format below verbatim.
4. Consolidate into `.claude/work/<slug>/review.md`:
   - Merge duplicates, keeping the highest severity.
   - Drop findings whose `path:line` doesn't show the problem (read it).
   - Sections: BLOCKER, MAJOR, MINOR, then the tests reviewer's traceability table.
   - Last line: `CHANGES REQUIRED` if any BLOCKER/MAJOR, else `APPROVED (N minors)`.
5. Show the user the BLOCKER/MAJOR list and the verdict. Fixes go through
   `/implement-slice` with the findings.

## Findings format
One line per finding, most severe first:
`[BLOCKER|MAJOR|MINOR] path:line — problem — consequence or failing scenario — fix`.
Report only what you can point to in the code; none → `No findings`. A
violated rule cites its file and section.

| Severity | Means |
| --- | --- |
| BLOCKER | Security or authZ hole, PII leak, data loss, wrong payment/booking state, an in-scope Then-step not met, a contract break for released apps |
| MAJOR | Wrong behaviour on an error or edge path; a required test missing (401, someone-else's-404, error code, scenario); a rule violation with a real consequence |
| MINOR | Naming, style, readability or a cheap cleanup with no behaviour impact |
