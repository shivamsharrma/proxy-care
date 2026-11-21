---
paths:
  - "proxy-care-server/**"
---
# Spring backend

## Structure
- Hexagonal per bounded context (see `proxy-care-server/CLAUDE.md`).
- `domain`: aggregates, value objects, domain events, ports. No framework
  imports. Invariants enforced in constructors/factory methods.
- `application`: use-case services, `@Transactional` boundary lives here.
- `adapter.in.web`: controllers, request/response records, validation
  (`jakarta.validation`). Controllers are thin: map → call use case → map.
- `adapter.out.*`: JPA entities and repositories, Kafka producers, provider clients.
- ArchUnit test fails the build on any layer violation.

## API
- REST under `/api/v1`, JSON, kebab-case paths, camelCase fields.
- Errors as RFC 9457 `ProblemDetail` with a stable `type` code the client maps.
- State-changing endpoints accept an `Idempotency-Key` header and are safe to retry.
- Pagination is cursor-based. Timestamps ISO-8601 UTC (`Instant`). Money is
  `long` paise + `currency`, never `double`.
- Booking/visit state transitions go through one state-machine method per
  aggregate; illegal transitions return 409.

## Security
- Every endpoint authenticated with the Supabase JWT (resource server, JWKS)
  except health and provider webhooks (which verify signatures instead).
- Authorize by resource ownership in the use case (`booking.sponsorId == caller`
  or assigned caretaker), not just by role. See `supabase-auth-rls.md`.

## Persistence
- Flyway or Supabase migrations — one source of truth (`supabase/migrations`);
  JPA `ddl-auto=validate`.
- Optimistic locking (`@Version`) on aggregates that change concurrently
  (booking, payment request).

## Testing
- Unit tests for domain (no Spring context). `@WebMvcTest` for controllers.
- Integration tests with Testcontainers (Postgres, Kafka); no H2.
- Provider clients tested against WireMock stubs recorded from sandbox docs.

## Observability
- Structured JSON logs with `traceId`, `bookingId`; never PII or secrets.
- Micrometer metrics for provider calls (latency, errors) and consumer lag.
