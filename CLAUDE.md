# Proxy Care — monorepo

Proxy Care books a caretaker to take a patient to hospital on a family
member's behalf: booking, pickup and ride (Uber/Rapido), hospital services,
and payment requests the family pays (Razorpay).

| Path | What | Read |
| --- | --- | --- |
| `proxy-care-client/` | Flutter app (Android, iOS, web), Riverpod, go_router, Supabase auth | `ARCHITECTURE.md`, `docs/feature-guide.md`, `TESTING.md` |
| `proxy-care-backend/` | Spring Boot 4 API (Java 21), Flyway, Supabase Postgres; Razorpay/Uber/Maps behind infrastructure interfaces | `ARCHITECTURE.md`, `README.md` |
| `atdd/test-specs/<feature>/*.feature` | Gherkin acceptance specs — **the source of truth for behaviour** | `.claude/rules/testing.md` |
| `documents/` | PRD and UI/UX-state-for-API design | read only; ask before editing |
| `.claude/` | Agentic workflow: rules, skills, agents, hooks | `.claude/README.md` |

## Delivery workflow

`/ship-feature <feature-or-spec-path>` runs plan → failing tests → implement →
4 parallel reviews → quality gate → PR; each stage is also its own skill.
- **Slug:** `<feature-dir>-<spec-stem>` (e.g. `pickup-and-ride-05-caretaker-ride-payment`),
  else a kebab-case summary. Skills take it as an argument, else from the branch.
- **Branch:** `feat/<slug>`. **Artifacts:** `.claude/work/<slug>/` (gitignored).

## Always

- Behaviour comes from the `.feature` files. If a spec is ambiguous or lists
  an "open design question", stop and ask — never invent the behaviour.
- Tests first: a scenario gets a failing test before its implementation.
- A test looks wrong or must change to pass? Stop and report; never edit it.
- Stay inside the planned slice: no extra features, no speculative abstractions.
- Before editing, read the `.claude/rules/` files matching the paths you touch.

## Never

- Edit generated files (`*.g.dart`, `*.freezed.dart`, `lib/core/l10n/generated/`)
  by hand, or bless goldens locally (`make goldens` is CI/Linux only).
- Run mutating cloud commands (AWS, Supabase, Razorpay); MCP access is read-only.
  Deploys, migrations on shared DBs, refunds, pushes and PR creation need explicit
  human approval each time; without it, write the exact steps for a human.
- Git limits: `.claude/rules/git-and-pr.md`. Secrets, keys, authZ, PII:
  `.claude/rules/security.md`.
