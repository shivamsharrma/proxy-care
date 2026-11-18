# Architecture

How the Proxy Care client is structured, and the rules every feature
follows. The rules marked **enforced** are checked by
`test/architecture/dependency_rules_test.dart`, so breaking one fails CI.
The same Dart code runs on Android, iOS and web; platform specifics live
only in `android/`, `ios/`, `web/` and plugin adapters. A step-by-step
guide to adding a feature is in [docs/feature-guide.md](docs/feature-guide.md).

## Layers and dependency direction

```text
                 ┌────────────────────────────────────────┐
                 │ app.dart / main.dart / core/di          │  composition root
                 └───────────────┬────────────────────────┘
                                 │ wires
        ┌────────────────────────┼─────────────────────────┐
        ▼                        ▼                         ▼
  presentation  ───────────▶  domain  ◀───────────────  data
  (controllers,               (entities,                (DTOs, mappers,
   widgets)                    repository interfaces,    data sources,
                               use cases)                repository impls)
        │                        │                         │
        └──────────┬─────────────┴───────────┬─────────────┘
                   ▼                         ▼
                 shared                    core
       (models, widgets, extensions)  (config, di, error, network,
                                       router, security, theme, …)
```

Arrows point from the code that depends to the code it depends on.

- **Domain depends on nothing outside itself**, except the pure-Dart
  contracts `core/error/failure.dart`, `core/error/error_reporter.dart`,
  `core/config` and `shared/models`.
- **Data depends on domain.** It implements domain repository interfaces and
  uses core infrastructure (Dio, secure storage).
- **Presentation depends on domain.** It calls use cases and repository
  interfaces and never touches data-layer classes.
- **Core and shared depend on no feature.**
- **The composition root** (`main.dart`, `app.dart`, `core/di`, and each
  feature's `<feature>_providers.dart`) is the only code that knows both
  interfaces and implementations.

### Rules

| Rule | Enforced |
| --- | --- |
| Domain imports no Flutter (`package:flutter`, `material_ui`, `dart:ui`) | Yes |
| Domain imports no Dio, Riverpod, secure storage or `json_annotation` | Yes |
| Domain imports nothing from `data/` or `presentation/` | Yes |
| Types the domain uses (`shared/models`, `core/config`, `AppFailure`, `ErrorReporter`) are pure Dart | Yes |
| Infrastructure exceptions (`AppException`, `ErrorMapper`, `guardResult`, `decodeResponse`) are used only by core and data, never by domain, presentation or shared | Yes |
| Data imports nothing from `presentation/` | Yes |
| Presentation imports nothing from `data/` and no Dio | Yes |
| `core/` and `shared/` import no feature | Yes |
| DTOs never appear in domain signatures; mappers convert at the boundary | By review |
| Infrastructure is injected through providers, never constructed inside a class that uses it | By review |

## Layer responsibilities

| Layer | Contains | Must not |
| --- | --- | --- |
| **Domain** | Entities, repository interfaces, use cases. Business rules. | Know about HTTP, JSON, Flutter, Riverpod or storage. |
| **Data** | DTOs, mappers, remote and local data sources, repository implementations. | Leak DTOs or Dio types outside `data/`. Contain UI logic. |
| **Presentation** | Riverpod controllers (`Notifier`, `AsyncNotifier`) and widgets. | Call data sources or build DTOs. Hold business rules. |
| **Core** | Feature-agnostic infrastructure: config, DI, errors, networking, routing, security, theme, utilities, app-shell widgets, services. | Contain feature-specific logic. |
| **Shared** | Cross-feature value types, reusable design-system widgets, extensions. | Contain infrastructure or feature logic. |

## Folder conventions

```text
lib/
├── main.dart                Entry point: bootstrap, then runApp
├── app.dart                 Root widget (ProxyCareApp, MaterialApp.router)
├── app_routes.dart          The feature route modules (the only list of features)
├── core/
│   ├── config/              Env: compile-time configuration and validation
│   ├── connectivity/        Network connection status (connectivity_plus)
│   ├── constants/           Feature-agnostic constants, one file per topic
│   ├── di/                  Core providers, root container, bootstrap
│   ├── auth/                Authentication session and state, Supabase
│   │                        adapter, authorization, biometric gate
│   ├── error/               Exceptions, failures, error mapper, repository
│   │                        guard, crash reporter, global error handlers
│   ├── l10n/                ARB strings, generated localizations, error
│   │                        messages
│   ├── formatting/          Date/time rules, date, number and rupee formats
│   ├── lifecycle/           App lifecycle phases
│   ├── logging/             AppLogger and its redacting implementation
│   ├── network/             Dio client, interceptors, network errors
│   ├── notifications/       Push notification interfaces and coordinator
│   ├── observability/       Analytics and performance interfaces (no-op)
│   ├── platform/            The platform the app runs on
│   ├── router/              The single GoRouter: route definitions, modules,
│   │                        guards, deep links, notification entry point
│   ├── security/            Secure storage, redaction, session cleanup
│   ├── services/            Other cross-cutting services
│   ├── theme/               Design-system tokens, breakpoints, ThemeData
│   ├── utils/               Pure helpers
│   └── widgets/             App-shell widgets (no product screens)
├── features/
│   └── <feature>/
│       ├── <feature>_providers.dart
│       ├── data/
│       │   ├── datasources/
│       │   ├── dto/
│       │   ├── mappers/
│       │   └── repositories/
│       ├── domain/
│       │   ├── entities/
│       │   ├── repositories/
│       │   └── usecases/
│       └── presentation/
│           └── controllers/
└── shared/
    ├── extensions/
    ├── models/
    └── widgets/

test/                        Mirrors lib/
├── architecture/            Dependency-rule checks
├── core/
├── features/
├── shared/
├── fixtures/                Test data builders and sample sources
├── helpers/                 Test utilities (containers, rule checker)
└── mocks/                   mocktail mocks
```

Each `core/` and `shared/` folder has a short README describing what belongs
in it. Folders without code yet contain only that README (or a `.gitkeep`).

Naming:

- Files are `snake_case.dart`; one public type per file where practical.
- DTOs end in `Dto` (`UserDto`); mappers end in `Mapper` or are extensions
  named `<Dto>Mapper`; repository implementations end in `Impl`
  (`AuthRepositoryImpl`); controllers end in `Controller`.
- Providers end in `Provider` (`authRepositoryProvider`).

## Dependency injection

Riverpod is the only dependency-injection mechanism. There is no service
locator and no global mutable singleton.

### Where providers live

| Providers | File |
| --- | --- |
| Infrastructure (env, logger, error reporter, crash reporter, analytics, performance, formatters, error mapper) | `core/di/core_providers.dart` |
| Device services (connectivity, lifecycle, platform, push notifications, session cleanup) | `core/di/platform_providers.dart` |
| Routing (route modules, options, registry, router, notification navigator) | `core/di/router_providers.dart` |
| Networking (Dio, API client) | `core/di/network_providers.dart` |
| Authentication (Supabase, session, state, authorization) | `core/di/auth_providers.dart` |
| A feature's data sources, repositories and use cases | `features/<feature>/<feature>_providers.dart` |
| A feature's controllers | Next to the controller in `presentation/controllers/` |
| Root overrides | `core/di/app_container.dart` (`createAppContainer`) |

A repository provider is typed as the **domain interface**, and only the
feature's providers file names the implementation:

```dart
// features/auth/auth_providers.dart
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authRemoteSourceProvider)),
);

final signInProvider = Provider<SignIn>(
  (ref) => SignIn(ref.watch(authRepositoryProvider)),
);
```

### Provider kinds

| Kind | Use for |
| --- | --- |
| `Provider<T>` | Stateless objects: clients, data sources, repositories, use cases, derived values. |
| `NotifierProvider<N, S>` | Synchronous UI state that changes through methods. |
| `AsyncNotifierProvider<N, S>` | State loaded or changed asynchronously (most controllers). |

```dart
final visitFilterProvider =
    NotifierProvider<VisitFilterController, VisitFilter>(
  VisitFilterController.new,
);

class VisitFilterController extends Notifier<VisitFilter> {
  @override
  VisitFilter build() => VisitFilter.upcoming;

  void select(VisitFilter filter) => state = filter;
}

final profileProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, Profile>(
  ProfileController.new,
);

class ProfileController extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() async {
    final result = await ref.watch(getProfileProvider).call();
    // A Failure becomes AsyncValue.error holding the AppFailure.
    return result.getOrThrow();
  }
}
```

### Lifecycle and disposal

- Infrastructure providers are **kept alive** for the whole app (the plain
  `Provider` default).
- Screen-scoped state uses **`.autoDispose`**, so it is freed when no widget
  listens any more.
- Anything holding a resource (streams, timers, clients, loggers) releases it
  in **`ref.onDispose`**, registered right after it is created:

  ```dart
  final logger = Logger(/* ... */);
  ref.onDispose(logger.close);
  ```

- Use `ref.watch` inside `build` and provider bodies so dependencies are
  rebuilt when their inputs change; use `ref.read` only inside callbacks
  (button handlers, notifier methods).
- Never store a `Ref` or `WidgetRef` outside the provider or widget it
  belongs to.

### ProviderScope and overrides

- The app runs under **one** root container, created by `bootstrap()` and
  given to `UncontrolledProviderScope` in `main.dart`. Bootstrap needs the
  container before the first frame (for example to read the error reporter),
  which is why it is created outside the widget tree.
- `envProvider` has **no default**: `createAppContainer` overrides it with
  the validated `Env`. Reading it without an override throws.
- Tests build the same container with `createTestContainer` (in
  `test/helpers/`), which calls `createAppContainer`, adds overrides and
  disposes the container after the test. Widget tests use
  `ProviderScope(overrides: [...])`.
- Override with `overrideWithValue` for ready-made fakes and `overrideWith`
  when the fake needs `ref`. Overrides are for tests and environment
  wiring, not for switching behaviour in production code.

## Feature module conventions

Build a feature from the inside out (walkthrough:
[docs/feature-guide.md](docs/feature-guide.md)):

1. **Domain**
   - `entities/`: immutable business objects shaped by the business, not by
     the API. Freezed may be used for value equality (`freezed_annotation`
     is pure Dart); `json_annotation` may not.
   - `repositories/`: `abstract interface class AuthRepository` returning
     `Future<Result<T>>`.
   - `usecases/`: one action per class with a `call` method, depending only
     on repository interfaces.
2. **Data**
   - `dto/`: request and response classes matching the API exactly, using
     `json_serializable` (or Freezed with JSON).
   - `mappers/`: explicit conversion between DTOs and entities.
   - `datasources/`: talk to Dio or storage; return DTOs; parse bodies with
     `decodeResponse`; let transport errors propagate (Dio exceptions or
     `AppException`s).
   - `repositories/`: `AuthRepositoryImpl implements AuthRepository`; wrap
     each operation in `guardResult`, which maps infrastructure errors to an
     `AppFailure` and returns a `Result` (see [Errors](#errors)).
3. **Wiring**: `<feature>_providers.dart` registers data sources,
   repositories (typed as the interface) and use cases.
4. **Presentation**: controllers watch use-case providers and expose
   `AsyncValue` or plain state to widgets.
5. **Routes**: `<feature>_routes.dart` declares the feature's
   `RouteDefinition`s and a `RouteModule`, listed once in
   `lib/app_routes.dart` (see [Navigation](#navigation)).

A feature may use another feature's **domain** layer (entities, repository
interfaces, use cases), but never its data or presentation layers.

## DTO and domain mapping

DTOs mirror the API; entities mirror the business. They change for different
reasons, so they are separate types joined by an explicit mapper:

```dart
// data/dto/user_dto.dart: the API's shape
@JsonSerializable()
class UserDto {
  const UserDto({required this.id, required this.full_name, this.phone});
  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);
  final String id;
  final String full_name;
  final String? phone;
}

// domain/entities/user.dart: the business's shape (pure Dart)
class User {
  const User({required this.id, required this.name, this.phone});
  final String id;
  final String name;
  final String? phone;
}

// data/mappers/user_mapper.dart: the only place both are known
extension UserDtoMapper on UserDto {
  User toEntity() => User(id: id, name: full_name, phone: phone);
}
```

Rules:

- Only `data/` imports DTOs. Repository implementations map before returning.
- Mapping is explicit and tested; no `fromJson` on entities.
- API naming, nullability and wrapper envelopes stay in DTOs. Entities
  express what the business needs (required fields are non-nullable).
- When the API changes, only the DTO and the mapper change.

## Errors

Three kinds of error, each with its own type and its own layer:

| Kind | Type | Produced by | Seen by |
| --- | --- | --- | --- |
| Infrastructure exception | `AppException` (sealed): `NetworkException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `ValidationException` (field errors), `ServerException` (incl. `invalidResponse`), `TimeoutException`, `CancelledException`, `UnknownException` | `ErrorMapper` from Dio errors, HTTP statuses, the backend's problem details and serialization errors | Core and data only |
| Application failure | `AppFailure` (sealed): `NetworkFailure` (incl. timeouts), `UnauthorizedFailure`, `ForbiddenFailure`, `NotFoundFailure`, `ValidationFailure`, `ConflictFailure`, `BusinessRuleFailure`, `RateLimitedFailure`, `ServiceUnavailableFailure`, `ServerFailure`, `CancelledFailure`, `UnexpectedFailure` | Repositories, from an `AppException` (`toFailure()`) | Domain and presentation |
| Domain failure | subclasses of `DomainFailure` (an `AppFailure`) | Features, for business rules | Domain and presentation |

Programming errors (`Error`: `TypeError`, `StateError`, failed asserts) are
none of these. They are not caught by repositories; they reach the global
handlers.

The flow end to end:

```text
Dio / storage / JSON error
  → ErrorMapper → AppException            (core, data sources)
  → guardResult → Result.failure(AppFailure)   (repository)
  → controller state (AsyncValue / sealed state)  (presentation)
  → AppLocalizations.failureMessage(failure) → localized text  (widget)

Anything uncaught (framework, platform, zone)
  → global handlers → ErrorReporter
  → AppLogger (redacted) + CrashReporter (error type, stack, context only)
```

### Result

`Result<T>` (`shared/models/result.dart`) is `Success<T>(value)` or
`Failure<T>(AppFailure)`. Use an exhaustive `switch`, `fold`, `map` (value),
`flatMap` (chain operations that can fail) or `getOrThrow` (in an
`AsyncNotifier`, where the thrown failure becomes `AsyncValue.error`).

### Repository convention

```dart
@override
Future<Result<Profile>> getProfile() => guardResult(
  () async => (await _remote.fetchProfile()).toEntity(),
  mapper: _errorMapper,      // errorMapperProvider
  reporter: _errorReporter,  // errorReporterProvider
);
```

- Every public repository method returns `Future<Result<T>>` and never throws
  an `AppException` or a Dio type.
- `guardResult` catches `Exception`s only. It maps them with `ErrorMapper`,
  converts them with `toFailure()`, and reports unknown failures,
  unreadable responses and 5xx failures to the `ErrorReporter`. An
  `AppFailure` thrown inside the action passes through; an `Error` is
  rethrown.
- Data sources decode bodies inside `decodeResponse(() => Dto.fromJson(json))`,
  which turns a payload of the wrong shape into
  `ServerException.invalidResponse`. Outside that call a `TypeError` stays a
  bug.
- A repository that needs a domain failure checks the backend code before
  returning, for example
  `Failure(failure: ServerFailure(code: 'SLOT_TAKEN')) => const Failure(SlotUnavailable())`.

### Backend errors

Every error is an RFC 9457 problem details body, sent as
`application/problem+json` (backend ADR 0012):

```json
{
  "type": "urn:proxycare:problem:validation-error",
  "title": "Validation failed",
  "status": 422,
  "detail": "The request contains invalid values.",
  "instance": "/api/v1/patients",
  "code": "VALIDATION_ERROR",
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
  "timestamp": "2026-11-18T09:30:00Z",
  "errors": [{ "field": "age", "code": "Max", "message": "must be less than or equal to 120" }]
}
```

`BackendError.parse` reads `code`, `detail` (else `title`; logs only),
`errors` and `traceId` (plain `application/json` and JSON text are read
too). `errors` becomes `fieldErrors` (`field` → messages; an object-level
error, with an empty `field`, is under `''`). `traceId` is kept as
`AppException.traceId`, for logs and support. An endpoint with a different
structure passes its own `BackendErrorParser` to `ErrorMapper` (or to one
`fromResponse` call); the default is never guessed per response. The
standard codes are `BackendErrorCode`, the ADR 0012 table
(`MALFORMED_REQUEST`, `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`,
`METHOD_NOT_ALLOWED`, `NOT_ACCEPTABLE`, `CONFLICT`, `PRECONDITION_FAILED`,
`PAYLOAD_TOO_LARGE`, `UNSUPPORTED_MEDIA_TYPE`, `VALIDATION_ERROR`,
`BUSINESS_RULE_VIOLATION`, `PRECONDITION_REQUIRED`, `RATE_LIMITED`,
`INTERNAL_ERROR`, `UPSTREAM_ERROR`, `SERVICE_UNAVAILABLE`,
`UPSTREAM_TIMEOUT`); a missing or unknown code is kept as a raw string and
the HTTP status classifies the error.

The HTTP status is authoritative; the code only refines what the status
leaves open. Error handling never depends on `title`, `detail` or the field
messages, and none of them is shown to users. A 429 or 503 keeps its
`Retry-After` (seconds) as `ServerException.retryAfter`, then
`RateLimitedFailure.retryAfter` / `ServiceUnavailableFailure.retryAfter`.

| Status | Exception → failure |
| --- | --- |
| any 4xx with field errors | `ValidationException` → `ValidationFailure` |
| 400, 422 | `ValidationException`, unless the code is `BUSINESS_RULE_VIOLATION` → `BusinessRuleFailure` |
| 401 | `UnauthorizedException` → `UnauthorizedFailure` |
| 403 | `ForbiddenException` → `ForbiddenFailure` |
| 404, 410 | `NotFoundException` → `NotFoundFailure` |
| 408, 504 | `TimeoutException` → `NetworkFailure(isTimeout: true)` |
| 409, 412 | `ServerException` → `ConflictFailure` (reload, then retry with the new `ETag`) |
| 428 | `ServerException` → `ServerFailure` (the client did not send `If-Match`: a bug) |
| 429 | `ServerException` → `RateLimitedFailure` |
| 503 | `ServerException` → `ServiceUnavailableFailure` |
| other 4xx | `ServerException` → by code (`BUSINESS_RULE_VIOLATION`, `CONFLICT`, `PRECONDITION_FAILED`, `RATE_LIMITED`), else `ServerFailure` |
| other 5xx | `ServerException` → `ServerFailure` (`ServiceUnavailableFailure` if the code says so) |

### Presentation: user-facing messages

All user-facing text lives in ARB files (`lib/core/l10n/arb/`, English for
now). `UserErrorKind.of(failure)` (pure Dart) picks the message category;
`AppLocalizations.failureMessage(failure)` returns its localized text, and
`fieldErrorMessage(failure, field)` the text for a rejected form field (the
localized validation message by default; the backend's field text only when
a screen opts in, since it is not localized). Screens never show
`AppFailure.message`, backend messages, exception text or stack traces. A
cancelled operation has no message. Feature `DomainFailure`s show the
business-rule message unless the feature adds its own string.

### Crash reporting

`ErrorReporter` (`LoggerErrorReporter`) logs every unhandled error and
forwards a `CrashReport` to the vendor-independent `CrashReporter`
(`crashReporterProvider`, a `NoopCrashReporter` for the MVP; Firebase
Crashlytics is backlog LL-05). A `CrashReport` carries only the error type,
stack trace, context and whether it was fatal, never the error object or
its message, so healthcare information, patient data and tokens cannot reach
a crash-reporting service.

### Global handlers

- `FlutterError.onError` → `ErrorReporter` (context `flutter`), then the
  previous handler.
- `PlatformDispatcher.instance.onError` → `ErrorReporter` (context
  `platform`). The web engine never calls it, so:
- `runGuardedZone` wraps the whole start-up (`main.dart`) and reports
  uncaught asynchronous errors (context `zone`). Bindings are initialized
  inside the zone. Errors before the reporter exists (invalid configuration)
  go to the root zone, so a broken start-up fails loudly.
- `ErrorWidget.builder`: in release and profile builds a widget whose build
  throws renders as empty space, without exception text or stack trace; the
  error is still reported. Debug builds keep the framework's error widget.

## Authentication

Supabase Auth is the identity provider; details in
[AUTHENTICATION.md](AUTHENTICATION.md) and [SECURITY.md](SECURITY.md).

| Layer | Pieces | May use |
| --- | --- | --- |
| `core/auth` | `AuthenticationSession`, `AuthenticationState`, `SessionTokenRecovery`, authorization, `BiometricGate` | `core/network` abstractions |
| `core/auth/supabase` | `SupabaseAuthenticationSession`, secure `LocalStorage` / PKCE storage, `initializeSupabase` | Supabase SDK |
| `core/security` | `SecureKeyValueStore` | `flutter_secure_storage` |
| `core/network` | `AccessTokenProvider`, `UnauthorizedRecovery` | nothing from `core/auth` |
| `core/di/auth_providers.dart` | `supabaseAuthClientProvider`, `authenticationSessionProvider`, `authenticationStateProvider`, `sessionTokenRecoveryProvider`, `authorizationServiceProvider`, `biometricGateProvider` | everything above |

The Supabase SDK owns the token lifecycle (rotation, automatic refresh,
concurrent-refresh de-duplication, lifecycle pause and resume, session
persistence through our secure storage). The app maps its events to
`AuthenticationState` in one place (`SupabaseAuthenticationSession`) and
exposes them through `authenticationStateProvider`, whose subscription is
cancelled when the provider is disposed. Supabase is initialized once, by
`supabaseAuthClientProvider`, awaited in `bootstrap()`. Domain and
presentation see only `AuthenticationState` (pure Dart) and, where needed,
`AuthenticationSession`; architecture tests keep the SDK and secure storage
packages inside their folders.

## Networking

All HTTP goes through `ApiClient` (`apiClientProvider`), used only by data
sources. It is built on Dio, but no Dio type leaves `core/network` and
`core/di/network_providers.dart`.

```dart
// features/<feature>/data/datasources/profile_remote_source.dart
Future<ProfileDto> fetchProfile() async {
  final response = await _api.get(
    '/me', // resolved under <API_BASE_URL>/api/v1
    decode: (json) => ProfileDto.fromJson(json! as Map<String, dynamic>),
  );
  return response.data;
}
```

### Configuration

`DioFactory` sets the base URL to `Env.apiBaseUrl` plus `/api/v1/`
(`NetworkConfig.apiRoot`; `API_BASE_URL` stays the host, and its validation
is unchanged), so data sources pass resource paths only (`/patients/p1`).
Dio joins base URL and path as strings and collapses a doubled `/`, so a
path with or without a leading `/` lands under `/api/v1`; an absolute URL
(another origin) ignores the base. It also sets timeouts of 10 s (connect),
30 s (receive) and 30 s (send; only for requests with a body, because on
web Dio warns about a send timeout without one), JSON content type and
`Accept: application/json, application/problem+json`. `PublicEndpoints`
match the full path, including `/api/v1`.

### Interceptor order

Dio runs request, response **and** error interceptors in the order they
were added (checked against Dio's source and by `dio_factory_test.dart`):

| # | Interceptor | Request phase | Response / error phase |
| --- | --- | --- | --- |
| 0 | `ImplyContentTypeInterceptor` (Dio) | content type | — |
| 1 | `CorrelationIdInterceptor` | sets `X-Correlation-Id` (kept across retries) | — |
| 2 | `LoggingInterceptor` | starts the timer | one line per attempt, including the 401 before a refresh |
| 3 | `AuthInterceptor` | attaches `Authorization: Bearer` from `AccessTokenProvider` (not for `skipAuth`, public endpoints or other origins) | 401: token from `UnauthorizedRecovery` (newer or refreshed), replay once |
| 4 | `RetryInterceptor` | — | transient failures: retry with backoff |

A repeat (3) or retry (4) runs through the whole chain again, so it gets a
fresh token and its own log line with the same correlation ID, and is marked
so no interceptor starts another loop for it. Errors are mapped to
`AppException`s once, by `DioApiClient`, after the chain.

### Retries

GET only, by default: connection errors, connection timeouts and HTTP 502,
503, 504, and a 429 that carries `Retry-After`; at most 3 retries,
0.5 s / 1 s / 2 s apart. On a 429 or 503, `Retry-After` (seconds) is
honoured: the wait is at least that long; one longer than
`NetworkConfig.maxRetryAfter` (10 s) is not waited out, and the error
reaches the caller with its `retryAfter`. Never: cancelled requests, other
methods (unless the request passes `RetryPolicy.always`, for example with
an idempotency key), or `RetryPolicy.never`.

### Responses

A 2xx is a success. `ResponseParser` reads `{"data": …}` (a resource) or
`{"data": […], "page": {"nextCursor", "hasMore", "size"}}` (a collection),
hands `data` to the typed decoder and returns `page` as
`ApiResponse.page`; `ResponseFormat.raw` hands the whole body instead, for
endpoints without that shape. Empty bodies (204) decode as `null`; a body
without `data` or with a malformed `page` is
`ServerException.invalidResponse`. `ApiResponse.headers` keeps the response
headers (lower-case names), with `etag` and `location` getters. Non-2xx
responses are mapped by `ErrorMapper` (see [Errors](#errors)).

### Request options

`ApiRequestOptions` carries per-request headers, receive / send timeouts,
`RequestCancellation`, `RetryPolicy`, an idempotency key (sent as
`Idempotency-Key`; generate with `IdempotencyKey.generate()`) and
`ifMatch` (sent as `If-Match`: the stored `ApiResponse.etag` of the
version being updated; versioned resources answer 428 without it and 412
when it is stale) and `skipAuth` (sign-in and token-refresh calls).
Pagination uses `PageRequest` (`?cursor=…&size=…`, size 20 by default,
1–100) and `CursorPage.fromResponse` (`page.nextCursor`, `page.hasMore`).

### Logging and privacy

Each attempt is logged as method, path, status and duration. Hosts, query
values, headers and bodies are not logged; debug builds add headers with
secrets masked and query parameter names. Body logging is off and, if
enabled, masks credentials and personal or health fields (`Redactor`).

## Navigation

One `GoRouter` (`routerProvider`), assembled from feature `RouteModule`s
listed in `lib/app_routes.dart` and validated by `RouteRegistry`. Every
route declares a `RouteAccess` (public, guest-only, or authenticated with
optional roles, permissions and feature); pure guards
(`DeepLinkGuard`, `AuthenticationGuard`, `AuthorizationGuard`) run as the
top-level redirect and again whenever the authentication state changes.
Interrupted locations travel in the `from` query parameter and are
sanitized before reuse. Redirect destinations are configurable through
`routerOptionsProvider`; until product screens exist they fall back to
router placeholders under `/_/`. Identity is always in path parameters,
extras are optional. Notification taps enter through
`notificationNavigatorProvider`. Details: [docs/navigation.md](docs/navigation.md)
and [docs/deep-linking.md](docs/deep-linking.md).

## Application initialization

`main()` → `runGuardedZone(...)` → `bootstrap()` → `runApp`:

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `Env.fromEnvironment()` reads and validates the `--dart-define` values.
   An invalid configuration throws `EnvConfigException` before anything
   else starts.
3. `createAppContainer(env:)` creates the root `ProviderContainer`, with
   `envProvider` overridden. Infrastructure providers build lazily from it.
4. `installGlobalErrorHandlers(...)` sends `FlutterError.onError` and
   `PlatformDispatcher.onError` to the `ErrorReporter` (logger by default;
   override `errorReporterProvider` for a crash-reporting service), and
   `installErrorWidgetBuilder()` keeps error details out of failed widgets
   outside debug builds.
5. `main` passes `routeModulesProvider.overrideWith(...)`, built from
   `enabledRouteModules(env)` (the feature modules plus, when enabled, the
   development-only widget showcase), to `bootstrap(overrides:)` and runs
   `ProxyCareApp` inside `UncontrolledProviderScope(container: ...)`;
   `ProxyCareApp` uses `MaterialApp.router` with `routerProvider`.

Inside `bootstrap()`, after the error handlers, Supabase Auth is
initialized and the session restored, date formatting data is loaded
(`AppFormatters.initialize`), and the session-following services start
(`sessionCleanupProvider`, `pushNotificationCoordinatorProvider`).

Bootstrap contains no feature logic. Future infrastructure that must be ready
before the first frame is added as an extra step inside `bootstrap()`.

## Cross-cutting services

Shared by every feature; each is an interface with a local or no-op
default, so no vendor SDK is required.

- **Logging:** `loggerProvider` (`AppLogger`): levels, structured fields,
  redaction, environment-aware minimum level. See
  [docs/observability.md](docs/observability.md).
- **Observability:** `CrashReporter`, `AnalyticsService` (always filtered),
  `PerformanceMonitor`; no-op until adapters are added (same doc).
- **Localization:** ARB + gen-l10n, English; conventions in
  `lib/core/l10n/README.md`.
- **Formatting:** `appFormattersProvider` (`AppFormatters`) for every
  user-facing date, time, number and amount; `date_time_rules.dart` states
  the rules: instants in UTC, shown in IST; civil dates never converted;
  amounts in integer paise.
- **Connectivity:** `connectivityStatusProvider`: online/offline from the
  device's network interfaces. Not proof that the API is reachable; never
  skip a request because of it.
- **Lifecycle:** `appLifecyclePhaseProvider` (foreground, inactive,
  background, detached) for services to `ref.listen`.
- **Platform:** `appPlatformProvider`, the only device information read.
- **Push notifications:** `PushMessagingService` (unavailable until a
  provider is chosen) and `DeviceTokenRegistry` (no endpoint yet), joined
  by `PushNotificationCoordinator`: registers the token while signed in,
  deletes and unregisters it when the session ends, and passes tapped
  payloads to `NotificationNavigator`.
- **Security utilities:** `Redactor`, `SessionCleanup`, analytics filtering
  and privacy-safe crash reports; conventions in SECURITY.md.

## Shared code conventions

| Kind | Location | Rule |
| --- | --- | --- |
| Value types used across features (`Result`) | `shared/models` | Pure Dart, immutable, value equality |
| Reusable UI components | `shared/widgets` | Design-system based; no providers or feature knowledge |
| Extensions | `shared/extensions` | One file per extended type, named `<Type>X` |
| Pure helpers | `core/utils` | Stateless, unit-tested |
| Constants | `core/constants` | `abstract final class` namespaces, one file per topic |
| Common interfaces (`ErrorReporter`, `AppFailure`) | `core/error` (and the matching `core/` folder) | Interface in pure Dart; implementation registered in `core/di` |

If something is used by only one feature, it stays in that feature.
