# Proxy Care backend

Spring Boot 4.1 (Java 21) API shared by the Proxy Care User and Caretaker apps.
Supabase provides Postgres, phone-OTP auth and storage; this service is the only writer of business data.

How it is built (layers, request flow, key decisions): [ARCHITECTURE.md](ARCHITECTURE.md).

## Prerequisites

- Java 21
- Docker (tests start a PostGIS container with Testcontainers; `docker compose` runs the app locally)

## Build and test

```sh
./gradlew clean build      # compiles and runs every test
```

## Run locally

```sh
docker compose up --build  # PostGIS + the app (profile `local`) on http://localhost:8080
```

- Health: http://localhost:8080/actuator/health. API docs: http://localhost:8080/swagger-ui/index.html.
- `/actuator/info` shows the build version and, when built from a git checkout, the commit. The Docker build context
  has no `.git`, so a Docker image shows build info only.
- Compose creates a stub `auth.users` table (`docker/auth-stub.sql`), because `profiles` references Supabase's auth
  schema.
- Alternative: run `supabase start` (Supabase CLI). It gives real Postgres + Auth on http://localhost:54321; point
  `DB_URL` and `SUPABASE_URL` at it and run `./gradlew bootRun --args='--spring.profiles.active=local'`.

## Environment variables

| Variable | Required | Purpose |
|---|---|---|
| `DB_URL` | yes | JDBC URL of Supabase's **session pooler** (the direct connection is IPv6-only) |
| `DB_USER`, `DB_PASSWORD` | yes | the dedicated backend Postgres role (never the service-role API key) |
| `DB_POOL_SIZE` | no (10) | Hikari max pool size |
| `SUPABASE_URL` | yes | e.g. `https://<ref>.supabase.co`; gives the token issuer and JWKS |
| `SPRING_PROFILES_ACTIVE` | yes | `local` or `prod` |
| `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` | not yet | payments |
| `GOOGLE_MAPS_API_KEY` | not yet | hospital search and ETA |
| `UBER_CLIENT_ID`, `UBER_CLIENT_SECRET` | not yet | rides |

The app fails to start when a required value is missing. Copy `.env.example` to `.env` for local values; never
commit `.env`.

## Getting a test JWT

Tokens are verified against Supabase's JWKS (ES256 or RS256), so you need a real Supabase Auth:

- **Supabase project:** add a test phone number with a fixed OTP (Dashboard → Authentication → Phone), sign in from the
  app or with `supabase-js` `signInWithOtp` + `verifyOtp`, and use the returned `access_token`.
- **Local:** `supabase start`, then sign in the same way against http://localhost:54321.

Call the API with `Authorization: Bearer <access_token>`. A user needs a `profiles` row to have roles.

## How to add a feature

1. Create `com.proxycare.features.<feature>` with the sub-packages it needs (ARCHITECTURE.md → Layers).
2. Add a migration `V<n>__<name>.sql` that enables RLS on every new table (`RlsEnabledTest` checks this).
3. Write the tests first (see below), then the controller, `I<Feature>Service` and its implementation.

## How to add an infrastructure provider

1. Create the capability interface in `com.proxycare.infrastructure.<capability>` and the implementation in
   `<capability>.<provider>` (ARCHITECTURE.md → Layers).
2. Add a `@ConfigurationProperties` record for the provider's keys, an entry in `.env.example` and a row above.

## How to add an error code

1. Add a constant to `ErrorCode` with its HTTP status. Never rename or reuse an existing code: the apps switch on it.
2. Throw the matching subclass: `ServiceInputException`, `BusinessException` or `SystemException` (with the cause).
   The message is returned to the client, so never put personal data in it.
3. Tell the app teams so they add the English and Hindi text for the new code.

## How to write tests

- **Unit test:** plain JUnit, no Spring, for pure logic.
- **Integration test:** `extends IntegrationTest`, for anything that needs Spring, the database or HTTP. It gives you
  `mockMvc`, `objectMapper`, `testDb`, `mutableClock` and `testTokens`. Every test
  starts with empty tables and the clock at 2026-01-15 10:00 IST.

Rules:

- **Data:** set it up with `TestDb`. Never mock the database or repositories.
- **Time:** `mutableClock.set(...)` / `mutableClock.advance(...)`. Never `Thread.sleep`.
- **Auth:** `testTokens.forUser(id, phone)`, or `bearer(id)` for the header. Negative cases:
  `testTokens.builder(id, phone).expired() / .issuer(..) / .audience(..) / .signedWithOtherKey() / .rs256()`.
- **Errors:** `ApiErrorAssert.assertApiError(result, status, code)`.
- **Context:** no `@MockitoBean`, `@TestPropertySource` or other context changes; they start a second context and
  database container.
- **Test-only tables** go in the `test_support` schema (`src/test/resources/db/testmigration`), never in `public`.
- **Naming:** `<Thing>Test`, in the same package as the class it tests.
