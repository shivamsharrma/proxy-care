# ADR 0010: Virtual threads enabled; JUnit Jupiter 6

- Status: Accepted. Supersedes the "virtual threads stay off" point of ADR 0001.
- Date: 2026-11-18

## Context

Milestone 01 asks for virtual threads "where compatible" and for "JUnit 5". ADR 0001 kept
virtual threads off until measured and did not discuss the JUnit major version.

## Decision

### Virtual threads: enabled (`spring.threads.virtual.enabled=true`)

Compatibility on Java 21:

| Component | Status |
|---|---|
| Tomcat request handling, `@Async`, `@Scheduled` | Supported by Spring Boot 4.1 |
| PostgreSQL JDBC 42.7 | Uses `ReentrantLock` rather than `synchronized` on its I/O paths, so carrier threads are not pinned during queries |
| HikariCP 7 | Compatible |
| Remaining `synchronized` blocks in libraries | Can pin a carrier thread on Java 21 (fixed in Java 24, JEP 491). Not a correctness problem, only a throughput one |

Consequences and guards:

- **The connection pool, not the thread count, is the concurrency limit.** With virtual threads,
  thousands of requests can wait on 10 connections. `connection-timeout` (5 s) bounds that
  wait; a timeout surfaces as 503 `SERVICE_UNAVAILABLE` once the error mapping exists
  (Milestone 02).
- Outbound vendor calls must be limited by Resilience4j bulkheads (ADR 0009), not by thread pools.
- `ThreadLocal`-heavy code is avoided; MDC values are per-request and cleared.
- Load testing (Milestone 15) records pinning with JFR (`jdk.VirtualThreadPinned`). If pinning
  hurts, the switch is one property.

### Test platform: JUnit Jupiter 6

Spring Boot 4.1.2 manages `org.junit:junit-bom` 6.0.3. JUnit 6 keeps the Jupiter programming
model and `org.junit.jupiter.*` packages of JUnit 5, so tests read as "JUnit 5 style".
Forcing JUnit 5 would fight the Boot BOM and the Spring test framework built against it.

## Consequences

- No code depends on the threading model; disabling virtual threads needs no code change.
- Test dependencies follow the Boot BOM; no separate JUnit version is pinned.
