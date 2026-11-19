# Proxy Care backend

Spring Boot 4.1 (Java 21) API shared by the Proxy Care User and Caretaker apps.
Supabase provides Postgres, phone-OTP auth and storage; this service is the only writer of business data.

Milestone progress: `docs/MILESTONES.md`. Deferred decisions: `docs/LATER.md`.

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
| `DB_URL` | yes | JDBC URL of Supabase's **session pooler** (see Database) |
| `DB_USER`, `DB_PASSWORD` | yes | the dedicated backend Postgres role (never the service-role API key) |
| `DB_POOL_SIZE` | no (10) | Hikari max pool size |
| `SUPABASE_URL` | yes | e.g. `https://<ref>.supabase.co`; gives the token issuer and JWKS |
| `SUPABASE_JWT_SECRET` | no | legacy HS256 secret; when set, it replaces JWKS |
| `RAZORPAY_WEBHOOK_SECRET` | yes | verifies Razorpay webhooks |
| `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` | not yet | needed once payments are built |
| `GOOGLE_MAPS_API_KEY` | not yet | hospital search and ETA |
| `UBER_CLIENT_ID`, `UBER_CLIENT_SECRET` | not yet | rides |
| `SPRING_PROFILES_ACTIVE` | yes | `local` or `prod` |

The app fails to start when a required value is missing. Copy `.env.example` to `.env` for local values; never
commit `.env`.

## Getting a test JWT locally

- **Supabase project:** add a test phone number with a fixed OTP (Dashboard → Authentication → Phone), sign in from the
  app or with `supabase-js` `signInWithOtp` + `verifyOtp`, and use the returned `access_token`.
- **Local HS256:** with `SUPABASE_JWT_SECRET` set (compose sets the Supabase CLI's public default), sign a token with
  that secret: `sub` = a user UUID, `aud` = `authenticated`, `iss` = `${SUPABASE_URL}/auth/v1`, `exp` in the future,
  plus a `phone` claim. Insert the user into `auth.users` (and `profiles` for roles) before calling the API.

## How to add a feature

One package per feature, about five files, with no layer sub-packages:

```
booking/
  BookingController.java   # HTTP only: validate, call the service, return a DTO
  BookingService.java      # business rules + @Transactional
  BookingRepository.java   # Spring Data JPA
  Booking.java             # JPA entity (extends BaseEntity)
  BookingDtos.java         # request/response records nested in one file, each response with static from(entity)
```

- Map entities to DTOs by hand in `from(...)`. Controllers never touch repositories, and entities never leave the service.
- Add a migration (`V<n>__<name>.sql`) with RLS enabled for every new table. `RlsEnabledTest` enforces this.
- Write the tests first, `extends IntegrationTest` (see "How to write tests").

## How to add an error code

1. Add a constant to `ErrorCode` with its HTTP status and an English title. Never rename or reuse an existing code:
   the apps switch on it.
2. Throw `new AppException(ErrorCode.YOUR_CODE, "Safe English detail.")`. Never put personal data in the detail.
3. Tell the app teams so they add the English and Hindi text for the new code.

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

## API responses

- **Success:** return the DTO directly (no `{ data: ... }` envelope). Use `201` for created and `204` for no content.
  Lists return `PageResponse<T>` (`items`, `page`, `size`, `hasNext`) built with `PageResponse.from(slice)`.
  The page size defaults to 20 and is capped at 100 by Spring Data's own settings.
- **Errors:** always RFC 9457 `application/problem+json`, with extra `code` and `requestId` fields (`errors[]` only for
  validation failures). The apps switch on `code` and show their own English/Hindi text; `detail` is a safe English fallback.
  Throw `AppException(ErrorCode.X, "safe detail")`; it is the only custom exception.
- **Request id:** every response has `X-Request-Id`. A client-sent value is kept only if it is a UUID.
- **Body limit:** bodies over 1 MB are rejected with 413 when they declare `Content-Length`. Chunked bodies are not
  checked, so the load balancer or proxy must also enforce a limit.

## Logging and personal data

- Never log request or response DTOs, entities or raw exception messages. Validation exceptions carry rejected values,
  such as a phone number. Don't add custom `toString()` methods to DTOs to work around this.
- Log only fields you chose explicitly, and wrap sensitive ones in `Mask` (`Mask.phone`, `Mask.fully`, `Mask.last4`).
- Sensitive data: phone numbers, pickup OTPs, Aadhaar last-4, PAN, bank details, health notes, live location and JWTs.
- Every request gets one access line (method, path, status, duration, userId). Bodies, query strings and headers are
  never logged. `prod` logs ECS JSON; `local` logs plain text with the requestId on each line.

## Authentication and authorization

The apps log in with **Supabase Auth** (phone OTP) and send `Authorization: Bearer <supabase access token>`.
The backend never handles OTPs or passwords.

- **Token check:** keys come from `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`. Both **ES256** (Supabase's default
  asymmetric key) and **RS256** are accepted. `iss` must be `${SUPABASE_URL}/auth/v1` and `aud` must be `authenticated`;
  `exp`/`nbf` are checked with 30 s of clock skew.
  TODO(verify): confirm which algorithm the real project's signing key uses (Supabase dashboard → JWT Keys).
- **Legacy secret:** if `SUPABASE_JWT_SECRET` is set, HS256 with that secret is used *instead* (older projects, local dev).
  When it isn't set, HS256 tokens are rejected.
- **Who the caller is:** `sub` is the user id and `phone` comes from the token. Roles (`USER`, `CARETAKER`, `ADMIN`) are
  read from `profiles` on every request. A user without a profile is authenticated with no roles; `GET /api/v1/me`
  returns empty `roles`, which tells the app to show onboarding.
- **In controllers:** take `@AuthenticationPrincipal CurrentUser me` and guard role-only endpoints with
  `@PreAuthorize("hasRole('CARETAKER')")`.
- **Paths:**

  | Path | Access |
  |---|---|
  | `/actuator/health/**`, `/actuator/info` | public |
  | `/webhooks/**` | public; the signature is checked in code |
  | `/v3/api-docs/**`, `/swagger-ui/**` | public, but disabled in `prod` |
  | `/api/v1/**` | needs a valid token; an unknown path returns 404 |
  | everything else | **denied** (401/403, not 404) |

  The deny-by-default rule is deliberate: a controller mapped outside `/api/v1` can never become public by accident.
- **401 and 403** use the same problem JSON as every other error (`UNAUTHENTICATED`, `FORBIDDEN`).

### Authorization rules

- **Never** decide whose data to return from a user id in the request body or path. Always use `me.id()`.
- Enforce ownership in the query, e.g. `findByIdAndUserId(id, me.id())`. If nothing is found, return **404, not 403**,
  so callers can't probe which ids exist.

## How to make an endpoint idempotent

Endpoints that create orders, payment requests or payouts **must** require an `Idempotency-Key` header (a UUID the app
generates once per user action, e.g. per "Pay" tap, and reuses on retries).

```java
@PostMapping("/api/v1/bookings")
ResponseEntity<BookingDtos.Created> create(@RequestHeader("Idempotency-Key") String key,
                                           @Valid @RequestBody BookingDtos.Create request,
                                           @AuthenticationPrincipal CurrentUser me) {
    return idempotency.execute(me.id(), key, request, BookingDtos.Created.class,
            () -> ResponseEntity.status(201).body(bookingService.create(me, request)));
}
```

- **One transaction:** claiming the key, running the action (its DB writes join the same transaction) and storing the
  response happen together. If the action throws, everything rolls back and the client can retry with the same key.
- **Same key, same body:** the stored status and JSON body are replayed with `Idempotent-Replayed: true`. A concurrent
  duplicate waits for the first request, then gets the replay.
- **Same key, different body:** `422 IDEMPOTENCY_KEY_REUSED`. A key that isn't a UUID: `400 VALIDATION_FAILED`.
- **Still running:** a duplicate that waits longer than `proxycare.idempotency.lock-timeout` (default 3s) gets
  `409 IDEMPOTENCY_IN_PROGRESS` and should retry shortly.
- **Limitations:** only JSON responses are supported. Status and body are replayed; other headers such as `Location`
  are not. A rollback cannot undo calls to vendors: an action that calls Razorpay must also pass Razorpay a stable
  receipt or idempotency value.
- **Retention:** keys are kept for 24 hours; a daily job deletes older ones.

## JSON request DTOs (Jackson 3)

Boot 4 uses Jackson 3, which **rejects a request that omits a primitive field** (`int`, `boolean`, `long`) of a record:
the client gets `400 MALFORMED_REQUEST`. Use a primitive only for fields that are required; use `Integer`/`Boolean`
(and `@NotNull` if needed) for optional ones.

## How to add a webhook provider

Razorpay (`common/webhook/RazorpayWebhookController`) is the reference. Uber and RazorpayX follow the same pattern:

1. Add the provider's secret to `AppProperties` as `@NotBlank` (startup fails without it) and to `.env.example`.
2. Add the provider name to the `webhook_events.provider` check constraint in a **new** migration.
3. Add a controller under `/webhooks/<provider>` (public in `SecurityConfig`; no JWT) that:
   1. takes the body as `@RequestBody byte[]`, the exact bytes the provider signed;
   2. verifies the signature with `WebhookSignatures.verify(...)` → `401 WEBHOOK_SIGNATURE_INVALID` on failure;
   3. only then parses the JSON → `400 MALFORMED_REQUEST` if it isn't a JSON object;
   4. requires the provider's event id → `400 VALIDATION_FAILED` if it is missing;
   5. calls `WebhookInbox.recordIfNew(...)` and returns 200 quickly. Retries of the same event id are no-ops.
4. Handling event types (and setting `processed_at`/`error`) belongs to the feature that needs them, not the controller.
