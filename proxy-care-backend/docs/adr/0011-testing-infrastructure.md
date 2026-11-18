# ADR 0011: Testing infrastructure

- Status: Accepted
- Date: 2026-11-18

## Context

Milestone 02 establishes how every later milestone tests its code. The standards require real
infrastructure where behaviour depends on it, deterministic tests, no real vendors, and no
meaningless tests. Several choices trade speed against isolation and fidelity.

## Decisions

### 1. One database container per test JVM, truncation before each test

- One PostGIS container is shared by every Spring context in the run, and every integration
  test shares one cached Spring context (`@IntegrationTest`).
- `DatabaseCleaner` truncates all application tables before each integration test.
- Test classes run sequentially in one JVM.

**Alternatives considered.** A container per test class is slow: several seconds per class,
times dozens of classes. `@Transactional` rollback per test can't cover tests that commit, such
as concurrency tests, after-commit listeners and MockMvc requests on other threads, and it hides
bugs that only appear at commit.

**Consequence.** Parallel test execution would need a database per fork; that's deferred until the
suite is slow enough to need it.

### 2. Test-only Flyway fixtures

`src/test/resources/db/test-migration` holds repeatable migrations loaded only by the test
profile. `test_probe` lets the infrastructure be tested before any feature table exists. Using
repeatable (`R__`) migrations keeps them out of the versioned sequence, so they can never block
or reorder production migrations.

### 3. Vendor-call guard through JVM proxy settings

A JUnit launcher listener routes all non-local HTTP to a dead proxy. It's cheap, it covers IDE
runs too, and it's proven by a test. It relies on clients honouring `ProxySelector.getDefault()`,
which `RestClientFactory` does explicitly.

**Limitation.** A client that bypasses the JVM proxy settings, for example a vendor SDK with its
own HTTP stack and an explicit "no proxy" setting, would not be caught. Each SDK adopted in
`integrations` must be checked against the guard when it's added.

### 4. JWT fixtures without a production decoder

The ES256 test keys are generated per run, and the token builder, JWKS stub and test users exist
now. `TestJwtsTest` runs the fixtures through a reference decoder configured with ADR 0004's
rules, so the authentication milestone starts with proven fixtures and a ready-made list of scenarios. The
reference decoder is test code. It isn't a second implementation to keep in sync: the authentication milestone
replaces it with the production decoder.

### 5. WireMock 3.13.2 standalone

The last stable line (4.x is beta). The standalone artifact shades Jetty 11 and Jackson 2, so it
can't conflict with Boot 4.1's Tomcat or Jackson 3. Verified by the contract tests.

### 6. Coverage gate only where code exists

85% line coverage is enforced for each `in.proxycare.shared.*` package with code, and there's no
global gate. A global percentage over mostly empty modules is either meaningless or blocking.

### 7. Mechanical test conventions

ArchUnit rules on test code forbid `Thread.sleep`, raw `@SpringBootTest` (use `@IntegrationTest`),
`@DirtiesContext` and `@MockitoBean`, so conventions hold without relying on review alone.

## Consequences

- A clean checkout needs Docker and network access on the first run (Gradle distribution,
  dependencies, the PostGIS image). After that, tests need no network.
- Adding a Spring context variation (a different profile or extra configuration) costs a new
  context and should be rare. The `@IntegrationTest` rule makes it a deliberate exception.
