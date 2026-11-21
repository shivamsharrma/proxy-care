---
paths:
  - "atdd/**"
  - "proxy-care-client/test/**"
  - "proxy-care-client/maestro/**"
  - "proxy-care-backend/src/test/**"
---

# Testing standards

## Source of truth
`atdd/test-specs/<feature>/<nn>_<name>.feature`. Every test traces to a
scenario; code without a scenario needs a reason in the PR. Scenarios under
an "Open design questions" comment are out of scope until decided.

## Test pyramid (client)
| Level | Tool | For |
| --- | --- | --- |
| Unit | `flutter_test` + `mocktail` | Use cases, mappers, controllers, pure logic |
| Widget | `flutter_test`, provider overrides | Screen states (loading/data/error/empty), semantics |
| Golden | `goldenTest` helper, tag `golden` | Design-system components; blessed only in CI |
| E2E | **Maestro** | Gherkin scenarios on a real app build |

Client conventions are in `proxy-care-client/TESTING.md`: fakes over mocks,
override providers, deterministic (injected clock, no real network).

## Maestro ↔ Gherkin mapping (1:1)
How to write and run flows: the `write-maestro-flow` skill.
- `proxy-care-client/maestro/<feature>/<spec-stem>/<scenario-slug>.yaml`
  — one flow per Scenario. Scenario Outline: one flow per Examples row, or
  one shared flow driven by `env` from a thin wrapper flow per row.
- Flow header: `name` = the scenario title, `tags` copied from the Gherkin,
  and a `# spec: <path to .feature>` comment.
- Reusable steps (login as, open screen) are subflows in `maestro/_shared/`.
- Select by semantics label / id (`id:` or `text:` from ARB), not coordinates.
- Given / Background state is seeded through a test-only backend seed
  endpoint or seed SQL, never by clicking through other screens.
- When → taps/inputs; Then → `assertVisible` / `assertNotVisible`, with
  `enabled:` for enabled/disabled steps.

## Server
JUnit 5 + AssertJ, a real PostGIS container via Testcontainers, WireMock for
vendor gateways once they exist. For a helper not named here:
`proxy-care-backend/README.md` → How to write tests.

- **Unit test:** plain JUnit, no Spring, for pure logic (mappers, value rules).
- **Integration test:** `extends support/IntegrationTest` for anything needing
  Spring, the database or HTTP. It gives `mockMvc`, `objectMapper`, `testDb`,
  `mutableClock`, `testTokens`; every test starts with empty tables and the
  clock reset. All integration tests share one context and one container.
- **Data:** set up with `TestDb` (add a helper there when needed). Never mock
  the database or repositories.
- **Time:** `mutableClock.set(...)` / `.advance(...)`. Never `Thread.sleep`.
- **Auth:** `testTokens.forUser(id, phone)` or `bearer(id)`; negative cases via
  `testTokens.builder(...)` (`expired()`, `issuer(..)`, `audience(..)`,
  `signedWithOtherKey()`, `rs256()`). Every endpoint gets a 401 test; one
  that reads or changes an owned resource also gets a "someone else's
  resource is 404" test.
- **Errors:** `ApiErrorAssert.assertApiError(result, status, code)`.
- **Context:** no `@MockitoBean`, `@TestPropertySource` or other context
  changes — each starts a second context and container.
- **Schema:** test-only tables in the `test_support` schema
  (`src/test/resources/db/testmigration`), never `public`. RLS on every table
  is checked by `RlsEnabledTest`.
- **Naming:** `<Thing>Test` in the same package as the class under test;
  method names state the behaviour (`neverReturnsSomeoneElsesProfile`).

## Commands
The one place test and gate commands are written down; skills and agents
point here.

| Purpose | Client (from `proxy-care-client/`) | Server (from `proxy-care-backend/`) |
| --- | --- | --- |
| Codegen + format (fix) | `make gen` (after freezed/json/ARB changes), `make format` | — |
| Run specific tests | `flutter test <paths>` | `./gradlew test --tests '<fully.qualified.TestClass>'` — repeat `--tests` per class; `'com.proxycare.features.<feature>.*'` for a feature |
| Layer rules | `flutter test test/architecture` | covered by review (`backend-code.md`) |
| Full gate | `make get-locked`, `make gen`, `make format-check`, `make analyze`, `make test`, `make check-env ENV=development` | `./gradlew clean build` (Windows shell: `gradlew.bat clean build`) |
| E2E | `maestro test maestro/<feature>/ --include-tags smoke` | — |
| CI | `.github/workflows/ci.yml` | `.github/workflows/backend.yml` |

## Rules
- A new test fails for the right reason: the missing behaviour, or
  production types the plan names that don't exist yet — never a typo, a
  broken import, or a failure in existing code.
- Each test asserts the Then-step's observable result and is named after the
  scenario it covers (backend: method name states the behaviour).
- Cover error paths and the access-control specs, not just happy paths.
- Never weaken, skip, or delete a failing test to get green — fix the code or
  raise it. No `skip:`, `@Disabled`, or `--update-goldens` to pass CI.
- A check that didn't run (no device, tool missing) is reported `NOT RUN`
  with the reason — never PASS.
