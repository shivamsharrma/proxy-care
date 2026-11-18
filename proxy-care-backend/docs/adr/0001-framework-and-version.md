# ADR 0001: Framework, language and dependency versions

- Status: Accepted. The virtual-threads point is superseded by [ADR 0010](0010-virtual-threads-and-test-platform.md).
- Date: 2026-11-18
- Deciders: backend team

## Context

Proxy Care needs a backend that will run for years, handle payments and health information,
and be maintained by a small team. The engineering standards fix Java 21, Spring Boot and
Spring MVC. This ADR picks the exact release lines and the dependency policy.

Versions were checked on 2026-11-18 against Maven Central metadata and the Spring Boot
4.1.2 dependency BOM (`spring-boot-dependencies-4.1.2.pom`), not against blog posts.

| Release line | State on 2026-11-18 | Source |
|---|---|---|
| Spring Boot 4.2 | `4.2.0-RC2`, not GA | Maven Central `spring-boot` metadata |
| Spring Boot 4.1 | `4.1.2` GA, current on spring.io | Maven Central; spring.io project page |
| Spring Boot 4.0 | `4.0.9`; OSS support ends 2026-12-31 (third-party sources) | Maven Central; endoflife listings |
| Spring Boot 3.5 | OSS support ended 2026-06-30 (third-party sources) | endoflife listings |

The Spring Boot 4.1.2 system requirements page states Java 17 to 27 and Gradle 8.14+ or 9.x.

## Decision

### Language and runtime

- **Java 21 (LTS)**, Eclipse Temurin distribution, enforced with a Gradle Java toolchain
  (`languageVersion = 21`). The build must not depend on whichever JDK is on the `PATH`.
- Virtual threads (`spring.threads.virtual.enabled`) stay **off** at first. They interact with
  connection-pool sizing and `synchronized`-pinning in drivers. Enabling them is a separate,
  measured decision.

### Framework

- **Spring Boot 4.1.x** (start at 4.1.2), Spring MVC (servlet stack, embedded Tomcat).
- Do not adopt 4.2.0 while it is a release candidate. Plan the move to 4.2.x after its first
  patch release (4.2.1 or later) and before 4.1 OSS support ends. Confirm that date on the
  official Spring support calendar; third-party sources do not agree.
- Spring WebFlux is not used. The workload is request/response plus background jobs, and
  blocking JDBC is the persistence model (ADR 0003).

### Versions that come from the Spring Boot 4.1.2 BOM

These are **not** pinned separately. The Boot BOM is the single source of truth.

| Library | Managed version |
|---|---|
| Spring Framework | 7.0.10 |
| Spring Security | 7.1.2 |
| Hibernate ORM | 7.4.13.Final |
| Flyway | 12.4.0 |
| PostgreSQL JDBC | 42.7.14 |
| HikariCP | 7.0.2 |
| Jackson | 3.1.7 (Jackson 2 BOM 2.21.7 also present) |
| Micrometer / Micrometer Tracing | 1.17.2 / 1.7.2 |
| OpenTelemetry | 1.62.0 |
| Testcontainers | 2.0.5 |
| JUnit Jupiter | 6.0.3 |
| Mockito / AssertJ / Awaitility | 5.23.0 / 3.27.7 / 4.3.0 |
| Logback | 1.5.38 |

### Libraries outside the Boot BOM (pinned in the version catalog)

| Library | Version | Compatibility status |
|---|---|---|
| Spring Modulith (BOM) | 2.1.2 | **Verified**: its POM declares Spring Boot 4.1.2 / Framework 7.0.9 |
| ArchUnit (`archunit-junit5`) | 1.5.1 | Verified on Maven Central; no Spring coupling |
| Resilience4j (`resilience4j-spring-boot4`) | 2.4.0 | **To verify in Milestone 01**: built against Boot 4.0.0 / Framework 7.0.2 (runtime scope). Expected to work on 4.1, not yet proven |
| Bucket4j (`bucket4j_jdk17-core`, `bucket4j_jdk17-postgresql`) | 8.22.0 | No Spring coupling; PostgreSQL module to be checked against our schema ownership (ADR 0007) |
| ShedLock (`shedlock-spring`, `shedlock-provider-jdbc-template`) | 7.11.0 | **To verify in Milestone 01** against Spring Framework 7.0 |
| springdoc-openapi (`springdoc-openapi-starter-webmvc-ui`) | 3.2.0 | **To verify in Milestone 01** against Boot 4.1 and Jackson 3 |
| WireMock | to be chosen | **To verify**: needs a release that works with Jetty 12 and Jackson 3 |

"Verified" means the published POM declares a matching Spring line. "To verify" means
Milestone 01 must add a smoke test (context starts, the library's auto-configuration is
active, one behaviour works) before any feature depends on the library. If a library fails
that check, we record the failure in this ADR and choose again. We never silently substitute
a different library.

### Fallback for Resilience4j

If `resilience4j-spring-boot4` 2.4.0 does not work on Boot 4.1, the fallback is to use the
Resilience4j **core** modules (`resilience4j-circuitbreaker`, `-retry`, `-bulkhead`) wired
programmatically in `shared.integration`, with Micrometer binding through
`resilience4j-micrometer`. That fallback has no Spring coupling. Spring Framework 7's
built-in `@Retryable` / `@ConcurrencyLimit` is **not** a replacement: it has no circuit
breaker.

### Build tool

- **Gradle with the Kotlin DSL**, single project (not multi-project, see ADR 0002).
- **Gradle 9.x wrapper.** 9.9.1 is current (built 2026-11-10). Pin the newest 9.x patch that
  has been out for at least two weeks when Milestone 01 starts. Commit
  `distributionSha256Sum` in `gradle-wrapper.properties` and validate the wrapper in CI
  (`gradle/actions/wrapper-validation`).
- **Version catalog** `gradle/libs.versions.toml` for everything outside the Boot BOM and for
  plugin versions. The Boot and Modulith BOMs are imported with Gradle's native
  `platform(...)`; the `io.spring.dependency-management` plugin is not used.
- **Dependency locking** (`dependencyLocking { lockAllConfigurations() }`) with committed
  lockfiles, so a transitive upgrade is a reviewed diff.
- No dynamic versions (`+`, `latest.release`, ranges).
- Renovate or Dependabot opens upgrade PRs. Upgrades are merged only with green CI.

### Compiler settings

- `-Xlint:all -Werror` on main sources, `-parameters` (needed for Spring MVC binding and
  records).
- JSpecify null-safety annotations (Spring Framework 7 uses them). NullAway is a candidate
  for a later milestone, not a Milestone 01 requirement.

## Alternatives considered

- **Spring Boot 4.2.0-RC2.** Rejected: release candidate; the standards require stable,
  verified dependencies.
- **Spring Boot 4.0.x.** Rejected: OSS support ends 2026-12-31, six weeks from now.
- **Spring Boot 3.5.x.** Rejected: OSS support has ended.
- **Java 25 (LTS).** Java 25 is newer and Boot 4.1 supports it, but the standards fix Java 21.
  Moving to 25 later is cheap with toolchains. Record it as a future ADR, not now.
- **Maven.** Viable. Gradle was chosen (user decision, 2026-11-18) for toolchains,
  version catalogs and dependency locking.

## Consequences

- Jackson 3 (`tools.jackson.*` packages) is the JSON stack. Some third-party libraries still
  expect Jackson 2. Each such library is a compatibility risk and is checked at adoption.
- Spring Security 7 changes several defaults compared with 6.x. Security configuration must
  be explicit (ADR 0004), which the standards require anyway.
- A 4.1 → 4.2 upgrade must be scheduled in 2027.

## Verification required in Milestone 01

1. `./gradlew build` on Temurin 21 with `-Werror`.
2. Smoke tests for Resilience4j, ShedLock and springdoc as described above.
3. CI runs on Linux with Docker (Testcontainers) and caches Gradle.

## Verification results (Milestone 01, 2026-11-18)

Run on Temurin 21.0.13 with Gradle 9.8.2 (wrapper pinned by SHA-256), Docker 29.9.

| Item | Result |
|---|---|
| Build with `-Xlint:all -Werror` | Passes |
| Resilience4j 2.4.0 (`resilience4j-spring-boot4`) on Boot 4.1.2 | **Verified**: the application context starts with its auto-configuration and a `CircuitBreakerRegistry` bean (`ProxyCareApplicationTest`). Annotation-driven behaviour is exercised when the first client uses it (Milestone 06) |
| springdoc 3.2.0 | **Verified**: `/v3/api-docs` serves OpenAPI 3.1.0 with Jackson 3 (test and local run). springdoc also lists 3.1.x–3.2.x for Boot 4.1.x |
| ShedLock 7.11.0 | On the classpath and compiles; the README lists Spring 7 / Boot 4 support. **Not yet exercised**: no `LockProvider` is configured until the first scheduled job (Milestone 04) |
| Bucket4j 8.22.0, MapStruct 1.6.3 | Compile and resolve; first used in Milestones 04 and later |
| google-java-format | **1.37.0 failed** with Spotless 8.11 (`NoSuchMethodError: JavaFormatterOptions$Style.valueOf`). Switched to 2.0.0, which works |
| WireMock | **Verified in Milestone 02**: `wiremock-standalone` 3.13.2 (last stable; 4.x is beta) runs beside Boot 4.1 and Jackson 3 in the contract tests (ADR 0011) |
| Boot 4.1 security default user | Boot creates an in-memory user with a logged, generated password; excluded via `UserDetailsServiceAutoConfiguration` on `@SpringBootApplication`, guarded by a test |
