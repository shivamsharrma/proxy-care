# ADR 0012: API contract — `/api/v1`, data envelopes, RFC 9457 problem details

- Status: Accepted. **Supersedes ADR 0005**, except the conventions this ADR repeats.
- Date: 2026-11-18
- Decision by: the product owner (Milestone 04 brief), over ADR 0005's client-compatibility argument.

## Context

ADR 0005 adopted the envelope the Flutter client already parsed
(`{success, data, error, meta}`). Milestone 04 requires RFC 9457 problem details for errors and
lighter success bodies. The client is changed to match in a separate task (see "Client
changes"). Until then the existing client can't call this API.

## Decision

### Paths and JSON

- Base path **`/api/v1`**, applied centrally to every `@RestController` in `in.proxycare`.
  Controllers declare only the resource path. Actuator and API documentation aren't under it.
- camelCase properties. Unknown request properties are rejected. Integer amounts reject
  fractions. Money is integer paise in fields ending in `Paise`.
- Timestamps are ISO-8601 with an offset, always UTC: `2026-11-18T09:30:00Z`.

### Success responses

| Case | Status | Body | Headers |
|---|---|---|---|
| One resource | 200 | `{"data": {…}}` | `ETag` when the resource is versioned |
| Created | 201 | `{"data": {…}}` | `Location: /api/v1/<collection>/<id>` (path-absolute), `ETag` |
| Collection | 200 | `{"data": […], "page": {"nextCursor": "…" or null, "hasMore": true, "size": 20}}` | |
| No content | 204 | none | |

### Pagination

- Request: `?cursor=<opaque>&size=<n>`. `size` defaults to **20**, minimum 1, maximum **100**.
  Outside that range → 422 `VALIDATION_ERROR` with an `errors` entry for `size`.
- `page.size` is the page size applied. `page.hasMore` says whether another page exists, and
  `page.nextCursor` is the cursor for it (`null` on the last page).
- Cursors are opaque, URL-safe strings. Clients pass them back unchanged and never parse them. A
  malformed or tampered cursor → 422 `VALIDATION_ERROR` with an `errors` entry for `cursor`.
- Paging is keyset-based: pages stay stable when rows are inserted.

### Errors: RFC 9457 problem details

Every error, including those produced by the security filters, the request-size filter and the
servlet container's error page, has `Content-Type: application/problem+json` and this body:

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
  "errors": [
    {"field": "age", "code": "Max", "message": "must be less than or equal to 120"}
  ]
}
```

- `type` is `urn:proxycare:problem:<code in kebab case>`, stable per code.
- `title` is fixed per code, `detail` is a short English sentence for developers. **Clients
  branch on `code`, never on `title` or `detail`,** and localize by `code`.
- `instance` is the request path without the query string. The query string can contain
  personal data.
- `traceId` identifies the request in server logs and traces. Quote it to support.
- `errors` is present only for field-level problems: `field` (property path, such as
  `patient.age` or `purposes[0]`; empty for object-level errors), `code` (constraint name such
  as `NotBlank`, `Max`, `UnknownProperty` or `InvalidFormat`), and `message` (English).
- Never included: stack traces, exception or class names, SQL, constraint names, vendor
  responses, or the rejected values.

### Error codes

| `code` | Status | When |
|---|---|---|
| `MALFORMED_REQUEST` | 400 | Unreadable JSON, unknown property, wrong type, missing or invalid query parameter |
| `UNAUTHENTICATED` | 401 | No or invalid credentials (also `WWW-Authenticate: Bearer`) |
| `FORBIDDEN` | 403 | Authenticated but not allowed |
| `NOT_FOUND` | 404 | Unknown resource, or one the caller may not see |
| `METHOD_NOT_ALLOWED` | 405 | Method not supported (`Allow` header lists those that are) |
| `NOT_ACCEPTABLE` | 406 | No acceptable representation for `Accept` |
| `CONFLICT` | 409 | Concurrent modification without `If-Match`, or a uniqueness/integrity conflict |
| `PRECONDITION_FAILED` | 412 | `If-Match` doesn't match the current version |
| `PAYLOAD_TOO_LARGE` | 413 | Request body over 1 MB |
| `UNSUPPORTED_MEDIA_TYPE` | 415 | Body type not supported (`Accept` header lists those that are). Multipart is disabled |
| `VALIDATION_ERROR` | 422 | Well-formed request with invalid values (`errors` lists them) |
| `BUSINESS_RULE_VIOLATION` | 422 | A domain rule refused the action |
| `PRECONDITION_REQUIRED` | 428 | `If-Match` missing where the resource requires it |
| `RATE_LIMITED` | 429 | Too many requests (`Retry-After` in seconds) |
| `INTERNAL_ERROR` | 500 | Anything unexpected |
| `UPSTREAM_ERROR` | 502 | A vendor failed or answered unusably |
| `SERVICE_UNAVAILABLE` | 503 | A dependency is unavailable or overloaded (`Retry-After` in seconds) |
| `UPSTREAM_TIMEOUT` | 504 | A vendor didn't answer in time |

New codes may be added. Clients must treat an unknown code by its HTTP status.

### Optimistic concurrency

- Versioned resources return a strong `ETag` (for example `"3"`). It's opaque to clients.
- Updates to versioned resources require `If-Match` with that ETag (or `*`):
  - missing → 428 `PRECONDITION_REQUIRED`;
  - stale → 412 `PRECONDITION_FAILED`;
  - a concurrent update that commits between the check and the write also → 412. The version
    check is enforced again by the database update.
- Without `If-Match`, a lost race is 409 `CONFLICT`.

### Requests

- JSON bodies are limited to **1 MB** (413). Multipart is disabled; files go to Supabase
  Storage through signed URLs (ADR 0009).
- Request DTOs are records validated with Bean Validation.

### Documentation

OpenAPI 3.1 at `/v3/api-docs`, also written to `build/openapi/openapi.json` on every test run.
It includes a `bearerAuth` scheme, shared `Problem`, `FieldValidationError` and `PageMetadata`
schemas, the error-code table, and the standard error responses on every operation.

## Unchanged from ADR 0005

- Versioning by path (`v1`); additive changes don't need a new version.
- Opaque string ids; upper-snake-case enum values; clients tolerate unknown enum values.
- The `Idempotency-Key` header (ADR 0007).

## Client changes

The Flutter client (`proxy-care-client/lib/core`) must:

1. Request paths under `/api/v1`.
2. Parse success bodies as `{data}` / `{data, page}` instead of `{success, data, error, meta}`.
   A 2xx is a success.
3. Parse `application/problem+json` errors: map `code` (string) to its error codes, `errors` to
   field errors, and `traceId` to the correlation id it records. Missing or unknown codes fall
   back to the HTTP status.
4. Use `cursor`/`size` and `page.nextCursor`/`page.hasMore` for pagination.
5. Honour `Retry-After` on 429/503, and send `If-Match` with the stored `ETag` on updates.

## Consequences

- Errors from every layer look the same, so client error handling is one code path.
- RFC 9457 is understood by generic HTTP tooling.
- The backend and client must switch together. The backend has no production endpoints yet, so
  nothing is broken in use today.
