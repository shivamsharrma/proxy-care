# Agentic delivery workflow

The control plane Claude Code uses to deliver Proxy Care features from the
Gherkin specs in `atdd/test-specs/`. Nothing here is product code.

## Pipeline

```text
/ship-feature <spec>
  ├─ /plan-feature ───────── feature-planner ──────────────► plan.md   ◆ GATE 1: human approves
  └─ per slice:
       ├─ /write-failing-tests ── test-writer ──────────────► failing tests (unit/widget + Maestro)
       ├─ /implement-slice ────── client-/backend-implementer ► green
       ├─ /review-changes ─────── 4 reviewers in parallel ──► review.md (BLOCKER/MAJOR → back to implement)
       ├─ /run-quality-gate ───── quality-gate-runner ──────► verify.md (VERDICT: PASS required)
       └─ commit
  /open-pr ────────────────── release-manager ──────────────► PR     ◆ GATE 2: human approves push + PR

Naming: skills are verbs (`/run-quality-gate`), agents are roles
(`quality-gate-runner`), rules are topics (`backend-code.md`); `client-` /
`backend-` match `proxy-care-client/` and `proxy-care-backend/`.
```

`/ship-feature` runs in the main thread because subagents cannot spawn subagents.
Artifacts live in `.claude/work/<slug>/` (gitignored). Ops: `/report-release-status`,
`/plan-rollback` (plans only — never deploys or merges).

## Layout

| Path | Purpose |
| --- | --- |
| `../CLAUDE.md` | Repo map, slug/branch, "always" and "never" rules |
| `rules/*.md` | Topic rules. `security.md`, `git-and-pr.md` (no `paths:`) load in every session and subagent; the rest load when matching paths are touched |
| `skills/<name>/SKILL.md` | Pipeline skills + domain skills |
| `agents/*.md` | Subagents; reviewers and feature-planner are read-only (`Read, Grep, Glob`) |
| `hooks/*.js` | Node hooks (Windows-safe, no deps) |
| `settings.json` | Permissions + hook wiring |
| `mcp/maestro-mcp.js` | Cross-platform launcher for `maestro mcp` |
| `../.mcp.json` | MCP servers |
| `../.claude-plugin/` | `proxy-care-sdlc` plugin + local marketplace |

### Where an instruction belongs
Each fact is written once; everything else points to it.

| Kind | Home |
| --- | --- |
| Invariants every session and subagent needs | `../CLAUDE.md`, `rules/security.md`, `rules/git-and-pr.md` (always loaded — never repeat them elsewhere) |
| What code must look like (conventions, limits) | `rules/` — e.g. `backend-code.md`, `testing.md` |
| Test and gate commands, NOT RUN semantics | `rules/testing.md` → Commands, Rules |
| How to do a task, step by step | `skills/` — they cite rule sections, never restate them |
| Review findings format and severity scale | `skills/review-changes/SKILL.md` → Findings format |
| A role: inputs, tools, output format | `agents/` — they name the rules and skill to read |
| Product architecture | `proxy-care-*/ARCHITECTURE.md`, backend `README.md` |

## Hooks

| Event | Script | Does |
| --- | --- | --- |
| PreToolUse `Bash\|PowerShell` | `guard-bash.js` | Blocks force/mirror pushes, pushes to `main`, `--no-verify`, `gh pr merge`, `rm -rf`/`Remove-Item -Recurse -Force`/`rmdir /s`, `git reset --hard`/`clean -f`, env dumps, secret reads (files, Secrets Manager, SSM), `supabase db push` |
| PreToolUse file tools | `guard-secrets.js` | Blocks Read/Edit/Write/Glob on `.env*` (not `.env.example`), keys, keystores, `key.properties`, `~/.aws`, `secrets/` |
| Stop, SubagentStop | `stop-checks.js` | ~0.4 s scan of **added** lines + untracked files: conflict markers, private/AWS/Razorpay-live/Supabase-secret/GitHub keys, `service_role` in client, `shared_preferences`, skipped/focused tests, `--update-goldens`, invalid `.claude` JSON. Hard 4 s budget; never blocks twice in a row |

Exit code 2 blocks and tells Claude why. Hooks fail open on malformed input
or git errors so infrastructure trouble never wedges a session. Hooks are a
guard-rail, not a security boundary — CI, branch protection and IAM are.

## MCP servers (`.mcp.json`)

| Server | Access | Setup |
| --- | --- | --- |
| `github` | Read-only endpoint | `GITHUB_PERSONAL_ACCESS_TOKEN` (fine-grained, read) |
| `supabase` | `read_only=true` | `SUPABASE_PROJECT_REF`; OAuth on first use |
| `aws` | `READ_OPERATIONS_ONLY=true` | `uv` installed; `AWS_PROFILE` (default `proxycare-readonly`) bound to a **ReadOnlyAccess** IAM role — the real enforcement; `AWS_REGION` (default `ap-south-1`) |
| `context7` | Docs lookup | none |
| `maestro` | `maestro mcp` | Maestro CLI on PATH + emulator/simulator |

Approve them once with `/mcp`. PRs are created with the `gh` CLI (behind an
`ask` permission and GATE 2), not through the GitHub MCP.

## Plugin

`.claude-plugin/plugin.json` packages the skills, agents, hooks and MCP
servers as `proxy-care-sdlc`, with a local marketplace at the repo root:

```text
/plugin marketplace add ./          # from the repo root
/plugin install proxy-care-sdlc@proxy-care
```

Inside this repo you don't need it — `.claude/` already loads everything;
installing both would register the hooks twice. The plugin is for reuse in
other checkouts. `CLAUDE.md` files and `rules/` are project context and are
not part of the plugin (the validator warns about this; expected).
Validate with `claude plugin validate .claude-plugin/plugin.json`.

## Local overrides

Personal settings go in `.claude/settings.local.json` and `CLAUDE.local.md`
(both gitignored).
