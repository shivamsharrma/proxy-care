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

## Database

- **Connection:** use Supabase's **session pooler** URL as `DB_URL`. It works over IPv4; the direct connection is IPv6-only
  unless you buy the IPv4 add-on. The transaction pooler needs `prepareThreshold=0` on the JDBC URL.
- **Schema:** Flyway owns it (`src/main/resources/db/migration`). Migrations are forward-only: never edit one after it has
  been applied; add a new one. Hibernate only validates (`ddl-auto=validate`).
- **Extensions** live in the `extensions` schema (Supabase convention); the connection's `search_path` is `public, extensions`.
- **Statement timeout:** every connection sets `statement_timeout = 5s`. This also applies to migrations; a slow data
  migration must `SET LOCAL statement_timeout` itself.

### DB role and RLS

- The backend connects as a **dedicated Postgres role**. It owns the tables, or has `BYPASSRLS`, and has only the grants
  it needs. It is **never** the Supabase service-role API key.
- Flutter apps never connect to the database or call Supabase tables directly. This service is the only writer.
- Every table we create has **RLS enabled with no policies**, which is deny-all for `anon` and `authenticated`. Anyone
  holding the public anon key therefore can't read or write our tables. `RlsEnabledTest` fails if a new table in
  `public` doesn't have RLS on.

### Persistence rules

- Put `@Transactional` only on service methods, and use `readOnly = true` for queries.
- Inject `Clock`; never call `Instant.now()`. Tests control it with `MutableClock`.
- Money is `long` paise (field names end in `Paise`). Never `double` or `float`.
- Time is stored as `timestamptz` in UTC. Use `Asia/Kolkata` only for business-time logic (e.g. "is the clinic open").
- Entities extend `BaseEntity` (UUID id, `createdAt`/`updatedAt` from the `Clock`, `@Version` optimistic locking).
