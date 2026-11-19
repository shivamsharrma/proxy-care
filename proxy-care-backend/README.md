# Proxy Care backend

Spring Boot 4.1 (Java 21) API shared by the Proxy Care User and Caretaker apps.
Supabase provides Postgres, phone-OTP auth and storage; this service is the only writer of business data.

## Build and test

Prerequisites: Java 21 and Docker (tests start a PostGIS container with Testcontainers).

```sh
./gradlew clean build
```

Configuration is read from environment variables; see `.env.example`.

Milestone progress: `docs/MILESTONES.md`. Deferred decisions: `docs/LATER.md`.

## How to write tests

Pick one of two kinds:

- **Unit test**: plain JUnit, no Spring. Use it for pure logic (masking, signatures, clocks).
- **Integration test**: `extends IntegrationTest`. Use it for anything that needs Spring, the database or HTTP.
  It gives you `mvc` (MockMvc), `json` (ObjectMapper), `db` (TestDb), `clock` (MutableClock) and `tokens` (TestTokens).
  Every test starts with empty tables and the clock at 2026-01-15 10:00 IST.

Rules:

- **Data:** set it up with `TestDb` (`insertAuthUser`, `count`, `truncateAll`; M2 adds `insertProfile`).
  Never mock the database or repositories.
- **Time:** control it with `clock.set(...)` / `clock.advance(...)`. Never use `Thread.sleep`.
- **Auth:** get tokens from `tokens.forUser(id, phone)`. For negative cases use
  `tokens.builder(id, phone).expired() / .issuer(..) / .audience(..) / .signedWithOtherKey() / .rs256()`.
- **Errors:** assert them with `ProblemJsonAssert.assertProblem(result, status, code)`.
- **Context:** don't add `@MockitoBean`, `@TestPropertySource` or other context changes to an integration test.
  They create a second Spring context and a second database container.
- **Test-only tables:** put them in the `test_support` schema (`src/test/resources/db/testmigration`), never in `public`.
- **Naming:** call test classes `<Thing>Test`, in the same package as the class they test.
