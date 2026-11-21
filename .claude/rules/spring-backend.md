---
paths:
  - "proxy-care-backend/**"
---
# Spring backend

Canonical source: `proxy-care-backend/ARCHITECTURE.md` (layers, decisions) and
`proxy-care-backend/README.md` (build, run, how to add a feature / provider /
error code / test). This is the checklist. Copy the `profile` feature when in doubt.

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
  (`domain-events.md`), never through another feature's repository or tables.
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
  (`ProfileNotFoundException`).
- The message reaches the client: never personal data in it.
- Vendor failures become `EXTERNAL_SERVICE_ERROR` / `EXTERNAL_SERVICE_UNAVAILABLE`
  inside the infrastructure gateway; they never leak to features.

## Identity and authorization
- The caller comes only from `ISecurityIdentityProvider`
  (`requireCurrentUserId()`), never from a path, query or body field.
- Someone else's resource is **404**, not 403.
- Roles are loaded from `profiles` through `IUserRoleProvider`; check with
  `hasRole(...)` / method security, and still check ownership.
- `SecurityConfig` is deny-by-default: only `/api/**` (authenticated), health,
  info, API docs and `/error`. A new public path is an explicit, tested change.

## Persistence
- Flyway migrations in `src/main/resources/db/migration/V<n>__<name>.sql`,
  forward-only — never edit an applied one.
- Every new table: `alter table … enable row level security;` with **no**
  policies, in the same migration (`RlsEnabledTest` enforces it).
- `ddl-auto: validate`, open-in-view off. Spring Data repositories or
  parameterized `JdbcTemplate`; no string-built SQL/JPQL.

## Vendors and config
- Per vendor: a `@ConfigurationProperties` record under `proxycare.<vendor>`,
  the env var in `application.yml`, `.env.example` and the README table.
- Only the vendor's gateway class calls the vendor; it has timeouts.

## Code style
- Constructor injection via Lombok `@RequiredArgsConstructor` + `private final`.
- Interfaces are `I`-prefixed (`IProfileService`); fields and parameters are
  named after the type without the prefix (`profileService`,
  `securityIdentityProvider`, `jdbcTemplate`).
- Small methods whose names say what they do, guard clauses over nesting,
  named constants and conditions. Comments and Javadoc explain why.

## Logging
- MDC keys only from `common/logging/MdcKeys` (`traceId`, `userId`).
- Never log personal data: phones, OTPs, identity documents, bank
  details, health notes, location, tokens. Log chosen fields only.

## Testing
See the Server section of `testing-standards.md`.
