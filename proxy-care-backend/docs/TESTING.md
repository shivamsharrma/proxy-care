# Testing

How the Proxy Care backend is tested: the tools, where tests live, the kinds of tests and their
rules, the shared support code, and how to run everything. Decisions and trade-offs are in
[ADR 0011](adr/0011-testing-infrastructure.md).

## Principles

- **Real where it matters.** Integration tests run against real PostgreSQL + PostGIS in a
  container, never a mocked database or an in-memory substitute.
- **Nothing external.** No test contacts Supabase, Razorpay, Uber or any other vendor, and no test
  needs credentials. Outbound HTTP goes to WireMock; anything else is blocked (see
  [Vendor-call guard](#vendor-call-guard)).
- **Deterministic.** Time comes from a controllable clock, ids from fixed generators, concurrency
  assertions hold for every interleaving, and nothing sleeps. Test order is randomised to expose
  hidden dependencies.
- **Meaningful.** A test states a behaviour someone relies on. Coverage is a by-product, never the
  goal.

## Stack

| Tool | Version | Source | Used for |
|---|---|---|---|
| JUnit Jupiter | 6.0.3 | Boot BOM | Test engine (JUnit 5 programming model, ADR 0010) |
| AssertJ | 3.27.7 | Boot BOM | All assertions |
| Mockito | 5.23.0 | Boot BOM | Mocks in unit tests; attached as a Java agent |
| Spring Boot Test | 4.1.2 | Boot BOM | Application context, `ApplicationContextRunner` |
| MockMvc (`MockMvcTester`) | Framework 7.0.10 | Boot BOM | API tests through the real filter chain |
| Spring Security Test | 7.1.2 | Boot BOM | `jwt()` authenticated requests |
| Spring Security OAuth2 JOSE / Resource Server | 7.1.2 | Boot BOM | JWT fixtures and the reference decoder (test scope only) |
| Testcontainers (+ PostgreSQL module) | 2.0.5 | Boot BOM | PostGIS container |
| PostGIS image | `postgis/postgis:17-3.5@sha256:01a6a70e…` (PostgreSQL 17.5, PostGIS 3.5.2) | Pinned in code | Test database |
| WireMock (standalone) | 3.13.2 | Version catalog | Vendor HTTP stubs |
| Awaitility | 4.3.0 | Boot BOM | Asynchronous assertions |
| ArchUnit | 1.5.1 | Version catalog | Architecture and test-convention rules |
| Spring Modulith Test | 2.1.2 | Modulith BOM | Module verification, module documentation |
| JaCoCo | 0.8.16 | Version catalog | Coverage report and verification |

Everything is resolved through Gradle and recorded in `gradle.lockfile`.

## Where tests live

Tests mirror the production package they test:

```
src/test/java/in/proxycare/
├── ProxyCareApplicationTest.java     whole application
├── architecture/                     ArchitectureTest, ModularityTest, TestConventionsTest
├── shared/
│   ├── config/                       configuration binding and start-up checks
│   ├── integration/                  HTTP client settings and WireMock contract tests
│   ├── jobs/                         scheduling on/off
│   ├── persistence/                  Flyway, PostgreSQL/PostGIS behaviour, concurrency
│   ├── security/                     security filter chain (MockMvc)
│   └── time/                         clock
└── support/                          shared test code (and tests for it)
    └── security/                     JWT keys, token builder, JWKS stub, test users
src/test/resources/
├── db/test-migration/                test-only Flyway fixtures (never deployed)
├── junit-platform.properties         random order, default timeouts
└── META-INF/services/                VendorCallGuard registration
```

Packages named in the standards with no code yet (`shared/api`, `shared/error`, `shared/money`,
`shared/idempotency`, `shared/outbox`, `identity`, `integrations`, `webhooks`) get their test
packages with their first production class. Empty placeholder test packages are not created.

**Naming.** Test classes are `<ClassUnderTest>Test`, or `<Topic>Test` for cross-cutting behaviour
(`ConcurrentWritesTest`). Contract tests against WireMock end in `ContractTest`. Test methods
are sentences about behaviour: `rejectsANegativeReadTimeout`, not `test1` or `testValidate`.

**Shape.** Arrange, Act, Assert, in that order. Blank lines separate the three; the comments
`// Arrange`, `// Act`, `// Assert` are used only where the sections are not obvious.

## Test categories

### Unit tests

- One class, no Spring context, no I/O, milliseconds to run.
- Mock only collaborators that are external to the unit (a port, a vendor client). Never mock
  value objects, the class under test, or the JDK.
- Cover success, failure and boundary cases (zero, negative, limits, missing values).
- Examples: `HttpClientSettingsTest` (validation boundaries), `DeploymentConfigurationValidatorTest`,
  `IntegrationTestExtensionTest` (Mockito).

### Integration tests

- Annotated with **`@IntegrationTest`**, nothing else on the class. It provides the full
  application, the `test` profile, the PostGIS container, MockMvc, a `MutableClock`, and a
  clean database before every test.
- Real SQL, constraints, transactions and Flyway migrations. Never mock the database layer.
- Examples: `PostgresPlatformTest`, `FlywayMigrationTest`, `ConcurrentWritesTest`.

### API tests

- `@IntegrationTest` plus `MockMvcTester`: requests pass through the real security filter chain,
  controllers, validation and exception handling.
- Assert status codes, response JSON and the error envelope with `ApiAssertions`.
- Authenticated callers come from `TestUser` (`user(1)`, `caretaker(2)`, `userAndCaretaker(3)`,
  `withoutRoles(4)`): `mvc.get().uri(...).with(TestUser.user(1).asRequest())`.
- Example: `SecurityFilterChainTest`.

### Contract tests (outbound HTTP)

- A real client built by `RestClientFactory` talks to a WireMock server (`WireMockSupport`).
- Verify the request sent (method, path, headers, JSON body), response deserialization, how
  4xx/5xx surface, timeouts, redirects, and retry behaviour where retry is allowed (ADR 0009).
- WireMock fails the test on any request no stub expects.
- Example: `RestClientFactoryContractTest`.

### Architecture tests

- `ArchitectureTest` (ArchUnit): layers, module boundaries, vendor SDK containment, money
  without floating point, injected clock, constructor injection.
- `ModularityTest` (Spring Modulith): module detection, cycles, allowed dependencies, plus
  generated module diagrams in `build/spring-modulith-docs`.
- `TestConventionsTest` (ArchUnit on test code): no sleeps, integration tests use
  `@IntegrationTest`, no `@DirtiesContext`, no `@MockitoBean`.

## Database

- **One PostGIS container per test JVM** (`PostgresTestcontainersConfiguration`), started on first
  use and removed by Testcontainers' Ryuk when the JVM exits. The image is pinned by digest and
  must match the Supabase PostgreSQL major version (open decision U12). It never depends on a
  local database: the container listens on a random port.
- **Prepared like production.** The container runs `docker/postgres/init/20-proxycare.sh`, which
  applies `database/setup/roles.sql`, the script used on Supabase. PostGIS lives in
  `extensions`, and the Supabase API roles exist (docs/DATABASE.md).
- **Real privileges.** Flyway connects as `proxycare_migrator` and the application as
  `proxycare_app`, so a missing grant or an over-broad one fails a test. Only test
  infrastructure uses the superuser: `AdminDatabase` for catalog checks and for acting as another
  role, and `DatabaseCleaner`. Connection settings are registered with a `DynamicPropertyRegistrar`
  rather than `@ServiceConnection`, which would force the superuser on both Flyway and the
  application.
- **Credentials** are fixed test-only values in that class, for a throwaway container.
- **Migrations:** Flyway runs every production migration plus `db/test-migration` at context
  start-up. Hibernate then validates the schema.
- **Isolation:** `DatabaseCleaner` truncates every table in `proxycare` except Flyway's history,
  **before** each integration test (so a crashed test cannot leak rows). Test classes run one at
  a time in one JVM (`maxParallelForks = 1`), so no two tests share the database concurrently.
- **Test-only fixtures:** `R__test_probe.sql` creates `test_probe` (raw SQL) and
  `test_probe_entity` (for `support.persistence.ProbeEntity`, a JPA entity over `BaseEntity`).
  They follow the same rules as real tables, including RLS. They are never in `src/main` and never
  deployed. Feature tests use their real tables and entities.

## Support code (`in.proxycare.support`)

| Utility | Purpose |
|---|---|
| `@IntegrationTest` | The single integration-test setup (one cached context for all) |
| `PostgresTestcontainersConfiguration` | The shared PostGIS container |
| `DatabaseCleaner` | Truncates application tables (as superuser) |
| `AdminDatabase` | Superuser SQL and `executeAs(role, sql)` for privilege tests |
| `persistence.ProbeEntity` | Test-only JPA entity for `BaseEntity`, `Money` and soft-delete tests |
| `MutableClock`, `ClockTestConfiguration` | Controllable UTC clock replacing the application `Clock`; reset to `2026-01-15T09:00:00Z` before each test |
| `TestIds` | Readable deterministic UUIDs (`TestIds.account(7)`) |
| `TestJson` | JSON mapper for unit tests, configured like the application's (verified by `ProxyCareApplicationTest`) |
| `ApiAssertions` | Success/error envelope assertions matching the Flutter client's parser |
| `WireMockSupport` | WireMock servers and client settings for contract tests |
| `Concurrently` | Releases N threads at once and collects their outcomes |
| `VendorCallGuard` | Blocks non-local HTTP for the whole test run |
| `security.TestJwtKeys` | ES256 keys generated per run; trusted and forged |
| `security.TestJwts` | Supabase-shaped token builder: valid by default, change one thing per test |
| `security.JwksStub` | Serves the trusted public key as a Supabase JWKS on WireMock |
| `security.TestUser` | Authenticated MockMvc callers with backend roles |

**Builders and entity factories.** There are no entities yet. Each feature module adds a
`<Entity>Fixtures` class next to its tests when its first entity appears, built on `TestIds`
and `MutableClock`. Fixtures produce valid objects by default; tests change one property to
express the case under test. No generic fixture framework.

## Security testing

`TestJwts` produces every token case authentication must handle; `TestJwtsTest` proves each is
accepted or rejected for the intended reason by a reference decoder configured with ADR 0004's
rules, with keys served by a WireMock JWKS:

| Case | Token |
|---|---|
| Valid | `TestJwts.valid(supabaseUrl, subject, clock.instant())` |
| Expired | valid, then `clock.advance(...)` past expiry plus the 30 s skew |
| Not yet valid | `.notBefore(later)` |
| Invalid signature | `.signedWith(TestJwtKeys.forged())` (same key id, different key) |
| Legacy shared secret | `.signedWithSharedSecret()` (HS256) |
| Wrong issuer | `.issuer("https://other-project.supabase.co/auth/v1")` |
| Wrong audience | `.audience("anon")` |
| Wrong role | `.role("anon")` or `.role("service_role")` |

Authorization cases use MockMvc with `TestUser`:

| Case | How |
|---|---|
| Unauthorized | no `.with(...)` |
| Forbidden (wrong role) | `TestUser.caretaker(1)` on a USER-only endpoint |
| Resource ownership violation | `TestUser.user(2)` requesting `user(1)`'s resource; ADR 0004 expects 404 `NOT_FOUND` |

Production authentication arrives in the authentication milestone. Its tests reuse these fixtures against the
production decoder and the API.

## Concurrency testing

- Use `Concurrently.run(threads, action)`: threads are released together by a latch; results and
  exceptions are collected with a bounded wait.
- Assert on outcomes that hold for every interleaving ("exactly one insert succeeded"), never on
  timing or order.
- For effects that happen later (events, scheduled jobs), use Awaitility with an `atMost` bound:
  `await().atMost(Duration.ofSeconds(10)).untilAsserted(...)`.
- `Thread.sleep` and `TimeUnit.sleep` are forbidden in test code (`TestConventionsTest`).
- Example: `ConcurrentWritesTest` (insert-if-absent and conditional update with one winner).

## Vendor-call guard

`VendorCallGuard` is a JUnit Platform launcher listener, so it applies to Gradle and IDE runs.
Before any test starts it routes every non-local HTTP(S) request to a proxy on a closed local
port. WireMock (localhost) and Testcontainers (Docker socket and localhost ports) are unaffected.
`VendorCallGuardTest` proves a request to an internet host fails locally.

The application's HTTP clients honour the JVM proxy settings, which is what makes the guard
effective. Any future client must be built with `RestClientFactory` or honour
`ProxySelector.getDefault()` in the same way.

## Configuration for tests

`application-test.yml`:

- `proxycare.environment: test`; scheduled jobs off (`proxycare.jobs.enabled: false`). A test that
  needs a job starts it explicitly (see `SchedulingConfigurationTest`).
- Flyway also loads `classpath:db/test-migration`.
- No vendor settings exist yet. As vendor clients arrive, their base URLs in tests point at
  WireMock (set per test class from the WireMock port), and credentials are fixed dummy values.

`junit-platform.properties`: random method and class order; a default timeout of 60 s per test
method so a hung concurrency test fails instead of stalling the build.

## Coverage

- `./gradlew jacocoTestReport` writes HTML and XML reports to `build/reports/jacoco/test/`. It also
  runs automatically after `test`.
- `jacocoTestCoverageVerification` (part of `check`) enforces **85% line coverage for every
  `in.proxycare.shared.*` package** that contains code. There is no global threshold while most
  modules are empty; feature modules get their own rule when their first use case lands.
- Baseline at Milestone 02 (2026-11-18): 150 of 155 lines (96.8%).
- Milestone 03 (2026-11-18): 284 of 290 lines (97.9%); `shared.money` 100%, `shared.persistence`
  97.4%, every other `shared` package 98–100%. The uncovered lines are `ProxyCareApplication.main`
  and two defensive branches.

## Commands

| Command | What it does |
|---|---|
| `./gradlew test` | All tests, then the coverage report |
| `./gradlew check` | Tests, formatting check, coverage verification |
| `./gradlew jacocoTestReport` | Coverage report (runs tests if needed) |
| `./gradlew clean build` | Everything, from scratch, plus the jar |
| `./gradlew test --tests '*ConcurrentWritesTest'` | One class |

Requirements: JDK 21 (or Gradle downloads one) and a running Docker engine.

**Network on first run.** Gradle downloads its distribution and dependencies, and Testcontainers
pulls the PostGIS image (and its Ryuk helper) through Docker. These are the only network accesses.
Test execution itself never contacts a vendor.

## CI readiness

The build produces everything a CI job needs, with no extra scripts:

| Output | Path |
|---|---|
| JUnit XML results | `build/test-results/test/*.xml` |
| Test report (HTML) | `build/reports/tests/test/` |
| Coverage (XML for tools, HTML for people) | `build/reports/jacoco/test/` |
| Module diagrams | `build/spring-modulith-docs/` |

`.github/workflows/backend.yml` (added in Milestone 01) runs `./gradlew clean build` on Ubuntu
with Docker and uploads these reports. The complete CI/CD pipeline is a later milestone.
