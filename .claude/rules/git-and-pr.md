# Git and pull requests

- **Branches** off `main`: `feat/<slug>` (slug per `CLAUDE.md`), `fix/<slug>`,
  `chore/<slug>`, `test/<slug>`. Never commit on `main`.
- **Never:** push to `main`, `git push --force` / `--force-with-lease` to a
  shared branch, rewrite published history, `--no-verify`, or merge a PR.
- **Commits:** imperative subject ≤ 72 chars matching the existing log
  ("Add ride status screen"), body says why. One logical change per commit;
  generated files and `pubspec.lock` committed with the change that caused them.
- **PRs** (`/open-pr`): into `main`, title like a commit subject. Body:
  1. Summary — what and why.
  2. Specs covered — `.feature` file + scenario names; any skipped and why.
  3. Tests — unit/widget/Maestro added; the `/run-quality-gate` table,
     NOT RUN checks included.
  4. Review — findings from the four reviewers and how each was resolved;
     open MINORs listed.
  5. Risk & rollback — migrations, flags, API / `ErrorCode` changes the
     released apps depend on.
  6. Last line: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Keep PRs reviewable (< ~400 changed lines excluding generated files);
  split by layer or scenario group otherwise.
- CI (`ci.yml` for the client, `backend.yml` for the backend) must be green;
  a red CI is fixed, not re-run until it passes.
