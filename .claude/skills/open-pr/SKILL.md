---
name: open-pr
description: "Pipeline stage 6: push the feature branch and open a GitHub PR into main with spec coverage, test, review and quality-gate evidence, via release-manager. Requires a PASS verdict from /run-quality-gate for HEAD and the user's approval; never merges."
argument-hint: "[slug]"
disable-model-invocation: true
---

# Open PR: $ARGUMENTS

1. Preconditions — stop and say which failed:
   - Not on `main`; `git status --porcelain` is empty.
   - `.claude/work/<slug>/verify.md` has `VERDICT: PASS` and a
     `Verified commit:` equal to `git rev-parse HEAD`. Otherwise run
     `/run-quality-gate` on the clean tree first.
   - `review.md` has no open BLOCKER/MAJOR.
2. Delegate to **release-manager**: draft title + body per `git-and-pr.md` →
   PRs from `plan.md`, `review.md` and `verify.md`; write the body to
   `.claude/work/<slug>/pr.md`.
3. **GATE 2:** show the user the title, body and `git log main..HEAD --oneline`;
   wait for explicit approval.
4. On approval, release-manager runs `git push -u origin <branch>`, then
   `gh pr create --base main --title "..." --body-file .claude/work/<slug>/pr.md`.
5. Report the PR URL and `gh pr checks` status.
