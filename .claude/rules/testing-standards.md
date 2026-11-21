# Testing standards

## Source of truth
`atdd/test-specs/<feature>/<nn>_<name>.feature` defines behaviour. Tests
trace back to scenarios; code without a scenario needs a reason in the PR.
Scenarios under an "Open design questions" comment are **not** to be
implemented until decided.

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
- `proxy-care-client/maestro/<feature>/<spec-stem>/<scenario-slug>.yaml`
  — one flow per Scenario (one per Examples row set for Outlines, using `env`).
- Flow header names its source and copies the Gherkin tags:
  ```yaml
  appId: com.proxycare.client
  name: "P9a shows the fare and that the request was sent"
  tags: [regression, caretaker-app, pickup-and-ride, P9a, payments, smoke]
  # spec: atdd/test-specs/pickup-and-ride/05_caretaker_ride_payment.feature
  ```
- Reusable steps (login as, open screen) are subflows in `maestro/_shared/`.
- Select by semantics label / id (`id:` or `text:` from ARB), not coordinates.
- Background `Given` state is seeded through a test-only backend seed
  endpoint or Supabase seed SQL, never by clicking through other screens.
- Run: `maestro test maestro/<feature>/ --include-tags smoke`.

## Server
JUnit 5 + AssertJ, Testcontainers (Postgres, Kafka), WireMock for providers,
ArchUnit for layering, pgTAP for RLS.

## Rules
- Write the failing test first; show it failing for the right reason.
- Each test asserts observable behaviour, names the scenario it covers.
- Cover error paths and the access-control specs, not just happy paths.
- Never weaken, skip, or delete a failing test to get green — fix the code or
  raise it. No `skip:`, `@Disabled`, or `--update-goldens` to pass CI.
