# ADR 0005: API response and error contract

- Status: Accepted (items marked *proposal* need client-team agreement)
- Date: 2026-11-18

## Context

The Flutter client already implements the contract it expects. The backend adopts it rather
than inventing a new one. Sources in the client:

- Envelope and error parsing: `lib/core/error/error_mapper.dart`, `lib/core/network/response_parser.dart`
- Error codes: `lib/core/error/backend_error_code.dart`
- Headers: `lib/core/network/network_config.dart`
- Pagination (marked provisional by the client): `lib/core/network/pagination.dart`

## Decision

### Envelope

Every JSON response, success or error, uses:

```json
{
  "success": true,
  "data": { "...": "..." },
  "error": null,
  "meta": {
    "timestamp": "2026-11-18T09:30:00Z",
    "correlationId": "7f0c2a2e-5b7d-4c1e-9a0e-3b1f2d6c8e11"
  }
}
```

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "fieldErrors": { "patient.age": ["must be between 0 and 120"] }
  },
  "meta": { "timestamp": "2026-11-18T09:30:00Z", "correlationId": "7f0c…" }
}
```

- Built by `shared.api` (`ApiResponse<T>` record and a `ResponseBodyAdvice` or explicit
  factory). Controllers return response records, never entities.
- `meta.timestamp` comes from the injected `Clock`, ISO-8601 UTC with `Z`.
- `meta.correlationId` is the request's correlation id (ADR 0006).
- **Errors always use a non-2xx status.** The client tolerates `success:false` inside a 2xx,
  but the backend never sends it.
- `204 No Content` has no body. File downloads (receipts) are not wrapped.

### Error codes and statuses

Exactly the client's `BackendErrorCode` set:

| `error.code` | HTTP | Used for |
|---|---|---|
| `VALIDATION_ERROR` | 400 for malformed/unreadable requests; 422 for well-formed requests that fail validation | Bean Validation failures, unknown JSON properties, bad enum values, idempotency-key reuse with a different body |
| `UNAUTHENTICATED` | 401 | Missing/invalid/expired token |
| `FORBIDDEN` | 403 | Valid token, wrong role or suspended account |
| `NOT_FOUND` | 404 | Unknown resource **or a resource the caller may not see** |
| `CONFLICT` | 409 | Optimistic-lock failure, idempotent request still in progress, state already changed |
| `BUSINESS_RULE_VIOLATION` | 422 | A domain rule refused the action (for example, cancelling a completed booking) |
| `RATE_LIMITED` | 429 | Rate limit; includes `Retry-After` |
| `REQUEST_TIMEOUT` | 408 | Server-side request deadline exceeded |
| `INTERNAL_ERROR` | 500 | Anything unexpected |
| `SERVICE_UNAVAILABLE` | 503 | Dependency down (DB, JWKS, vendor circuit open); includes `Retry-After` when known |

- One `@RestControllerAdvice` in `shared.error` maps exceptions to this table. Domain modules
  throw typed exceptions (`DomainRuleViolation`, `ResourceNotFound`, …) defined in
  `shared.error`, never Spring's `ResponseStatusException`.
- `error.message` is a short, generic, English developer message. It **never** contains
  exception messages, SQL, stack traces, vendor responses, ids of other users or PII. The
  client never shows it to users (it localizes by `code`).
- 500s are logged once with the stack trace and correlation id; the response is generic.
- `fieldErrors` keys are JSON property paths of the request (`patient.age`,
  `purposes[0]`). Messages are English and not localized (the client localizes by code).

### *Proposal*: business error reasons

`BUSINESS_RULE_VIOLATION` alone does not tell the client *which* rule failed. Proposal: add an
optional `error.reason` string (for example `BOOKING_NOT_CANCELLABLE`,
`PAYMENT_REQUEST_ALREADY_PAID`), stable and documented per endpoint. The client ignores
unknown fields today, so this is additive. Needs client agreement (U5).

### Conventions

- **Base path** `/v1`. Breaking changes need `/v2` for the affected resources; additive
  changes (new optional fields, new endpoints) do not.
- **JSON**: camelCase property names (matches the client's `fieldErrors`, `correlationId`).
  Null fields are included as `null` only where the field is part of the documented shape;
  absent optional values are omitted.
- **Unknown request properties are rejected** (400 `VALIDATION_ERROR`). A typo in a field
  name must not be silently ignored on a financial or health request.
- **Times**: instants are ISO-8601 UTC strings with `Z`. Calendar dates (visit date) are
  `YYYY-MM-DD`. How a pickup *wall-clock time* is represented depends on U7.
- **Money**: integers in paise, field names ending in `Paise` (`totalPaise: 124900`). Never
  floating point, never formatted strings. Currency is implicitly INR (single-currency product).
- **Ids**: opaque strings (UUIDs) in the API. Human-facing references (`PC-2481`) are separate
  fields, never used as lookup keys unless documented.
- **Enums**: upper snake case strings, matching the design document (`WAITING`, `ASSIGNED`).
  Clients must tolerate unknown values (new states are additive).
- **Pagination**: cursor-based. Request `?cursor=<opaque>&limit=<n>`; response
  `meta.nextCursor` (absent on the last page). `limit` default 20, maximum 100; above the
  maximum is a 400. The cursor is an opaque, URL-safe encoding of the sort key and id; clients
  must not parse it. The client marks these names provisional; this ADR confirms them unless
  the client team objects (U5).
- **Headers**: `X-Correlation-Id` (request, optional; response, always),
  `Idempotency-Key` (ADR 0007), `Retry-After` on 429/503.
- **Request size limits**: JSON bodies limited (configuration, initial 256 KB). Attachments are
  uploaded directly to Supabase Storage with signed upload URLs (ADR 0009), not through the API.

### Documentation

OpenAPI 3.1 generated by springdoc (subject to the Milestone 01 compatibility check, ADR
0001). The generated spec is committed and CI fails if it changes without the file being
updated, so every contract change is visible in review. Swagger UI is enabled only in local
and staging profiles.

## Alternatives considered

- **RFC 9457 Problem Details.** A good standard, but the client is already built against the
  envelope above. Switching would mean rewriting the client's error mapping for no product
  gain.
- **Offset pagination.** Rejected: unstable under inserts; the client already expects cursors.

## Consequences

- The error contract is a shared test fixture: contract tests in the backend assert the exact
  JSON shape the client's `ErrorMapper` parses.
- Every new domain exception must be mapped deliberately; an unmapped one becomes a 500,
  which an integration test per module guards against.
