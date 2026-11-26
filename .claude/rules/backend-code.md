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
- `common/`: security, errors, API shapes, web filters, persistence base,
  `model/` for value types shared across features (`Sex`, `MobileNumber`),
  and `validation/` for shared request rules (`PersonName`).
- `config/`: app-wide wiring that belongs to no single feature.
- Dependencies point one way: `features` → `infrastructure` interfaces →
  `common` → `config`. Never the reverse.

## Within a feature
- Controller → `I<Feature>Service` → `<Feature>Service` → repository.
  Controllers do HTTP only; entities never leave the service.
- Request/response bodies are records in `dto/`; responses are never entities.
  Validate requests with `jakarta.validation`. A field with a fixed set of
  values is an enum (`@NotNull Role role`, `@NotNull PreferredLanguage
  preferredLanguage`), never a `String` + `@Pattern`.
- Service methods return the response DTO (`ProfileResponse`), never a
  result wrapper; controller methods return that DTO directly (200, or 201
  via `@ResponseStatus(HttpStatus.CREATED)` for a create), no
  `ResponseEntity`.
- Create is `POST` (201); creating one that already exists is 409 with the
  feature's `*_ALREADY_EXISTS` code. Update is `PUT`, a full replace (200);
  updating one that doesn't exist yet is 404 with the feature's not-found
  code (`AppUserController`). Each service method reads as one flow: find
  or check, build or load, apply the request in the service (setters, with
  the mapper only to build a new object), save, map (`AppUserService`).
- Exception: `PUT /api/v1/profile/me` stays one create-or-update endpoint,
  because sign-in creates the profile or adds the app's role from the token
  (`ProfileService.updateCurrentProfile`).
- Mappers are MapStruct `@Mapper` interfaces (`AppUserMapper`): `to<Dto>(…)`
  for responses, `to<Entity>(request)` for a new entity built from a request
  (fields the server owns are `@Mapping(ignore = true)`). The Spring component
  model and `unmappedTargetPolicy=ERROR` are set once in `build.gradle.kts`.
- Mappers never modify an object in place: no `@MappingTarget`, no
  `update<Entity>(request, entity)` methods. A mapper only returns new objects;
  the service changes existing entities through their setters.
- Features talk to each other through a service interface or events
  (`backend-events.md`), never through another feature's repository or tables.
- `@Transactional` lives on service methods; `readOnly = true` for reads.

## Entities
- Extend `common/persistence/BaseEntity` (UUID id, audit timestamps from the
  `Clock`, `@Version`). Exception: ids that come from `auth.users` (see
  `ProfileEntity`, with the reason in a comment); such an entity still
  declares `@EntityListeners(AuditingEntityListener.class)`, `@CreatedDate
  createdAt` and `@Version version` itself.
- Entities are plain data holders: `@Getter`, `@Setter`, `@NoArgsConstructor`.
  No factory methods, mutators (`addRole`, `changeX`) or other create/update
  logic in an entity; the service builds and changes it through setters.
  Fields the framework owns (`createdAt`, `version`) get
  `@Setter(AccessLevel.NONE)`.
- Timestamps come from auditing (`@CreatedDate` / `@LastModifiedDate`, the
  `Clock`), never from a database default. Exception: soft delete.
- Soft delete: `@SoftDelete(strategy = TIMESTAMP, columnName = "deleted_at")`
  on the entity (`PatientEntity`). Hibernate stamps `deleted_at` with the
  database time on delete or orphan removal and leaves deleted rows out of
  every query; the entity has no `deletedAt` field.
- Enums are `@Enumerated(STRING)` in a `text` column (`text[]` for a set),
  stored and sent in JSON by their names (`EN`, `HI`): no Postgres enum types,
  `columnDefinition` casts, converters, codes or `@JsonValue`.
- Concurrency: `@Version` optimistic locking only (a conflict becomes 409
  `CONCURRENT_MODIFICATION` via `GlobalExceptionHandler`). No pessimistic
  `@Lock` lookups, retry loops, `TransactionTemplate` or `Persistable`/`isNew`
  unless a spec scenario needs them.

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
- The caller comes from `securityIdentityProvider.getAuthenticatedUser()`
  (`AuthenticatedUser`: `userId`, `phone`, `roles`) or
  `getAuthenticatedUserId()` in the service, never an id from a path, query
  or body field.
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
- Never `var`; always declare the exact type (main and test code).
- Constructor injection via Lombok `@RequiredArgsConstructor` + `private final`.
- Interfaces are `I`-prefixed (`IProfileService`); fields and parameters are
  named after the type without the prefix (`profileService`,
  `securityIdentityProvider`, `jdbcTemplate`). Local variables too:
  `ProfileEntity profileEntity`, `AuthenticatedUser authenticatedUser`,
  `ProfileUpdateRequest profileUpdateRequest`, never `result` / `status` /
  `request` / `saved`.
- Method names say exactly what they do (`buildProfileEntityWithoutRoles`,
  `toE164Phone`, `getAuthenticatedUser`), not `newX` / `normalized` / `handle`.
- Keep the public service method a short linear flow a reader follows top
  to bottom. Extract a helper only when it names a real concept; don't split
  one flow into several methods passing the same arguments around.
  Guard clauses over nesting; named constants.
- Comments only for a non-obvious why (a Hibernate quirk, an external
  format). No Javadoc that restates the method name or code; a contract is
  documented once, on the interface, not repeated on the impl or controller.

## Logging
- MDC keys only from `common/logging/MdcKeys` (`traceId`, `userId`).

## Testing
`testing.md` → Server and Commands. Step-by-step for a new
feature or vendor: the `build-backend-feature` skill.
