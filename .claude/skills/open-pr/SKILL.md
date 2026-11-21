---
name: open-pr
description: Push the feature branch and open a GitHub PR into main with spec coverage, review and verification evidence. Requires a passing verify report and user approval.
argument-hint: [slug]
disable-model-invocation: true
---

# Open PR: $ARGUMENTS

1. Preconditions (stop if any fails):
   - Current branch is not `main`; working tree clean (everything committed).
   - `.claude/work/<slug>/verify.md` ends with `VERDICT: PASS` and is newer
     than the last commit (else run `/verify` again).
   - `review.md` has no open BLOCKER/MAJOR.
2. Delegate to **release-manager** to draft title + body per
   `.claude/rules/git-and-pr.md` from `plan.md`, `review.md`, `verify.md`.
3. Show the user the title, body and `git log main..HEAD --oneline`.
   **Wait for explicit approval.**
4. On approval, release-manager runs:
   `git push -u origin <branch>` then
   `gh pr create --base main --title "..." --body-file .claude/work/<slug>/pr.md`.
   End the body with: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
5. Report the PR URL and `gh pr checks` status. Never merge.
