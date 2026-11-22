---
paths:
  - "proxy-care-backend/**"
---
# Spring backend

The checklist for backend code. Copy the `profile` feature when in doubt;
read `proxy-care-backend/ARCHITECTURE.md` only for a layering question this
file doesn't settle. Personal data never goes in an error message, log line
or event (`security.md` → PII).

## Layout (`com.proxycare`)
- `features/<feature>/`: `controller`, `dto/request`, `dto/response`, `service`,
  `repository`, `entity`, `mapper`, `event`, `listener`, `exception`, `enums`,
  `constants`. Create only the sub-packages the feature needs.
- `infrastructure/<capability>/`: the interface features depend on (business
  terms, no vendor names), its `model/` and `exception/`, and one sub-package
  per vendor (`razorpay/`) holding config, gateway, mapper and vendor DTOs.
- `common/`: security, errors, API shapes, web filters, persistence base.
- `config/`: app-wide wiring that belongs to no single feature.
- Dependencies point one way: `features` → `infrastructure` interfaces →
  `common` → `config`. Never the reverse.

## Within a feature
- Controller → `I<Feature>Service` → `<Feature>Service` → repository.
  Controllers do HTTP only; entities never leave the service.
- Request/response bodies are records in `dto/`; responses are never entities.
  Validate requests with `jakarta.validation`.
- Mappers are `@Component`s with `to<Dto>(…)` methods (`ProfileMapper`).
- Features talk to each other through a service interface or events
  (`backend-events.md`), never through another feature's repository or tables.
- `@Transactional` lives on service methods; `readOnly = true` for reads.

## Entities
- Extend `common/persistence/BaseEntity` (UUID id, audit timestamps from the
  `Clock`, `@Version`). Exception: ids that come from `auth.users` (see
  `ProfileEntity`, with the reason in a comment).
- `@Getter`, `@NoArgsConstructor(access = PROTECTED)`; no public setters.
  Enums `@Enumerated(STRING)`.

## API
- REST under `/api/v1`, kebab-case paths, camelCase JSON fields.
- Pages: `common/api/PageResponse.from(Page)` (offset; default size 20, max 100).
- Time: inject `Clock` (`config/time/ClockConfig`), store UTC, never `now()`
  without the clock. Money: `long` paise, never floating point.

## Errors
- One contract: `ApiError {code, message, fieldErrors, meta{traceId, timestamp}}`,
  produced only by `common/exception/handler/GlobalExceptionHandler` and the
  security handlers. Don't build error bodies in controllers.
- New failure → add an `ErrorCode` constant with its status (never rename or
  reuse one), then throw a subclass of `ServiceInputException`,
  `BusinessException` or `SystemException` (with the cause). Feature
  exceptions live in `features/<f>/exception/` with a `MESSAGE` constant
  (`ProfileNotFoundException`). The message reaches the client.
- Vendor failures become `EXTERNAL_SERVICE_ERROR` / `EXTERNAL_SERVICE_UNAVAILABLE`
  inside the infrastructure gateway; they never leak to features.

## Identity and authorization
Principle in `security.md` → Never trust the client; roles in `auth-and-rls.md`. In code:
- `securityIdentityProvider.requireCurrentUserId()` in the service, never an
  id from a path, query or body field.
- Scope repository lookups by the owner (`findByIdAndSponsorId(...)`) so a
  non-owner gets the feature's not-found `ErrorCode` (404).
- Role checks via `hasRole(...)` / method security, in addition to ownership.
- `SecurityConfig` is deny-by-default: only `/api/**` (authenticated), health,
  info, API docs and `/error`. A new public path is an explicit, tested change.

## Persistence
- Schema, Flyway and RLS rules: `auth-and-rls.md` → Schema and RLS;
  the steps: `write-db-migration` skill.
- `ddl-auto: validate`, open-in-view off. Spring Data repositories or
  parameterized `JdbcTemplate` (`security.md` → Input).

## Vendors and config
- Per vendor: a `@ConfigurationProperties` record under `proxycare.<vendor>`,
  the env var in `application.yml`, `.env.example` and the README table.
- Only the vendor's gateway class calls the vendor; it has timeouts.
- Webhooks: verify the signature on the raw body, dedupe event ids, answer
  2xx only after the change is stored. The path is public only through an
  explicit `SecurityConfig` change with a `PathAccessTest` case.

## Code style
- Constructor injection via Lombok `@RequiredArgsConstructor` + `private final`.
- Interfaces are `I`-prefixed (`IProfileService`); fields and parameters are
  named after the type without the prefix (`profileService`,
  `securityIdentityProvider`, `jdbcTemplate`).
- Small methods whose names say what they do, guard clauses over nesting,
  named constants and conditions. Comments and Javadoc explain why.

## Logging
- MDC keys only from `common/logging/MdcKeys` (`traceId`, `userId`).

## Testing
`testing.md` → Server and Commands. Step-by-step for a new
feature or vendor: the `build-backend-feature` skill.
