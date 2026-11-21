# Proxy Care — monorepo

Proxy Care books a caretaker to take a patient to hospital on a family
member's behalf: booking, pickup and ride (Uber/Rapido), hospital services,
and payment requests the family pays (Razorpay).

| Path | What | Guide |
| --- | --- | --- |
| `proxy-care-client/` | Flutter app (Android, iOS, web), Riverpod, go_router, Supabase auth | `proxy-care-client/CLAUDE.md` |
| `proxy-care-server/` | Spring Boot API, Kafka, Razorpay, Uber adapters (not scaffolded yet) | `proxy-care-server/CLAUDE.md` |
| `atdd/test-specs/<feature>/*.feature` | Gherkin acceptance specs — **the source of truth for behaviour** | `.claude/rules/testing-standards.md` |
| `documents/` | PRD and UI/UX-state-for-API design | read, don't edit without asking |
| `.claude/` | Agentic workflow: rules, skills, agents, hooks | `.claude/README.md` |

## Delivery workflow

Run `/ship <feature-or-spec-path>` for the full pipeline:
plan → failing tests → implement → 4 parallel reviews → verify → PR.
Each stage is also its own skill (`/plan-feature`, `/write-tests`,
`/implement`, `/review`, `/verify`, `/open-pr`). Work artifacts go in
`.claude/work/<slug>/` (gitignored).

## Rules that always apply

- Behaviour comes from the `.feature` files. If a spec is ambiguous or lists
  an "open design question", stop and ask — never invent the behaviour.
- Tests first: a scenario gets a failing test (unit/widget or Maestro flow)
  before the implementation.
- Topic rules live in `.claude/rules/`; read the ones matching the files you
  touch before editing.

## Never

- Push to `main`, force-push, or merge your own PR. Work on a branch, open a PR.
- Commit secrets, real tokens, `.env` files, keystores, or Razorpay/AWS/
  Supabase service keys. Never read them either.
- Put a Supabase `service_role` key or Razorpay `key_secret` in the client.
- Trust the client for authorization or payment success — the server decides.
- Edit generated files (`*.g.dart`, `*.freezed.dart`, `lib/core/l10n/generated/`)
  by hand, or bless goldens locally (`make goldens` is CI/Linux only).
- Run mutating cloud commands (AWS, Supabase, Razorpay). MCP access is read-only.
