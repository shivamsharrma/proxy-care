# ADR 0006: Logging, tracing and observability

- Status: Accepted (backend vendor unresolved: U9)
- Date: 2026-11-18

## Context

The backend processes phone numbers, addresses, health notes, Aadhaar/PAN references, bank
details and payments. Logs and telemetry are copied to third-party systems and kept for a long
time, so a single careless log line can leak protected data. At the same time, payment and
dispatch incidents must be traceable end to end.

The client sends `X-Correlation-Id` on each logical request (reused across its retries) and
expects it back as `meta.correlationId`.

## Decision

### Correlation id

- A servlet filter in `shared.logging`, ordered first:
  - Accepts an incoming `X-Correlation-Id` only if it matches `^[A-Za-z0-9-]{8,64}$`;
    otherwise (absent or invalid) generates a UUID. An invalid value is not echoed or logged
    (log-injection protection).
  - Puts it in the SLF4J MDC (`correlationId`), the response header and `meta.correlationId`.
  - Clears the MDC in `finally`.
- The id travels into asynchronous work: it is stored with event publications, webhook inbox
  rows and job runs, and restored into the MDC when they are processed.
- It is sent to vendors where they offer a reference field (for example Razorpay `notes`),
  never as a secret.

### Tracing

- Micrometer Tracing with the OpenTelemetry bridge; W3C `traceparent` propagation.
- `traceId`/`spanId` are added to the MDC beside `correlationId`. They answer different
  questions: the correlation id spans client retries; a trace spans one server request and its
  outbound calls.
- Outbound HTTP (`RestClient`), JDBC (via the datasource observation) and listener execution
  are instrumented.
- Export: OTLP to a collector. The backend vendor is unresolved (U9). Until it is chosen,
  sampling and export are off in production and logs are the source of truth. Sampling rate is
  configuration.

### Logging

- **Structured JSON** to stdout using Spring Boot's built-in structured logging
  (`logging.structured.format.console`), one event per line. Plain text only in the local
  profile.
- Standard fields: timestamp (UTC), level, logger, thread, message, `correlationId`,
  `traceId`, `spanId`, `accountId` (internal UUID, only when authenticated), `module`.
- **What is never logged** (engineering standard 9):
  - `Authorization` headers, JWTs, refresh tokens, API keys, webhook secrets or signatures.
  - Phone numbers, names, addresses, email, Aadhaar, PAN, bank account/IFSC, UPI ids.
  - Health information: visit purposes, health notes, instructions, attachments, hospital
    bill descriptions.
  - Request or response **bodies**, and vendor payloads.
  - Exception messages from vendors or the database (they often echo input). Log the
    exception type, the error code and our own message; stack traces only for unexpected
    errors.
- Enforcement, in three layers:
  1. **Allow-list by design**: log statements use structured key/values for ids and states,
     not `toString()` of DTOs. Request/response records that hold PII override `toString()`
     to redact (ArchUnit can require this for records in `..api..` packages that carry fields
     annotated `@Sensitive`).
  2. **Masking safety net**: a Logback converter/turbo filter masks patterns that look like
     JWTs, Indian mobile numbers, Aadhaar, PAN, IFSC and long digit runs. A safety net only;
     it is not relied on.
  3. **Tests**: a log-capture test per module runs typical flows with recognisable fake PII
     and asserts none of it appears in captured output.
- Spring/Tomcat request logging and Hibernate SQL parameter logging are **off** in every
  profile except an explicit local debugging profile that cannot be enabled in production
  (the profile refuses to start when `APP_ENV=production`).

### Metrics

- Micrometer; Prometheus scrape endpoint on the **management port**, not exposed publicly.
- Beyond Spring defaults (HTTP server, JVM, Hikari, Tomcat): Resilience4j state per vendor,
  outbox/event-publication backlog and age of the oldest incomplete publication, webhook
  inbox backlog and failures per provider, idempotency conflicts/replays, rate-limit
  rejections, JWKS refresh failures, job durations and lock misses.
- Metric tags never carry ids, phone numbers or other high-cardinality or personal values.

### Health and management

- Actuator on a **separate management port** bound to the internal network. Exposed
  endpoints: `health`, `info`, `prometheus`. All others disabled.
- Liveness: process only (never the database, so a DB outage does not restart every pod).
- Readiness: database reachable, Flyway schema version matches, JWKS available or cached.
  Vendor health is **not** part of readiness (a Razorpay outage must not take the API out of
  rotation); it is reported through metrics and circuit-breaker state.
- `health` details shown only to the management network.

### Audit trail (deferred)

Security and financial audit events (role changes, refunds, payouts, KYC decisions) are
**business records**, not logs. They go to an append-only table owned by the relevant module.
Designed in the feature milestones that create those actions.

## Alternatives considered

- **Only logs, no tracing.** Rejected: payment flows cross webhooks, async listeners and
  vendors; traces are the practical way to follow them.
- **Logging request/response bodies at DEBUG.** Rejected: one misconfigured level leaks
  health data.

## Consequences

- Choosing an observability vendor (U9) also requires a data-processing review, because it
  receives operational data from an Indian health service (U11).
