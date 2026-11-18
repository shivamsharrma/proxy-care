# ADR 0009: External integration architecture

- Status: Accepted (vendor-specific details verified in each vendor's milestone)
- Date: 2026-11-18

## Context

Vendors: Razorpay (payments, refunds), RazorpayX (payouts, bank-account verification), Google
Maps (places, geocoding, routing), Uber (rides; the PRD also mentions Rapido), HyperVerge (KYC),
Firebase Cloud Messaging (push), Freshdesk (support tickets), Supabase Storage (attachments,
bills, photos).

Every one of them can be slow, down, rate-limited, or return an error whose message contains
the data we sent. Some calls move money. Tests must never call a real vendor (standard 19).

## Decision

### Shape: ports in features, clients in `integrations`

```
feature module (e.g. billing)
  application/port/PaymentGateway          ← interface in domain language (Money, ids)
  infrastructure/RazorpayPaymentGateway    ← adapter: maps domain ↔ vendor client types
                     │
                     ▼
integrations.razorpay
  RazorpayClient                           ← typed requests/responses (records), auth,
  RazorpaySignatureVerifier                  signing, error translation, resilience
  RazorpayProperties (@Validated)
```

- **Ports** are defined by the feature that needs them, in its own vocabulary. The domain and
  application layers never see vendor types.
- **`integrations.<vendor>`** is transport only: HTTP, authentication, signatures, typed vendor
  DTOs, and translation of vendor failures into a small exception set. It knows nothing about
  bookings or caretakers. Each vendor package publishes only its client, its verifier and its
  DTOs (`@NamedInterface`).
- **Adapters** live in the feature's `infrastructure` layer.

### HTTP clients

- Spring Framework 7 **`RestClient`** over the JDK `HttpClient`, one instance per vendor, built
  in `shared.integration` with explicit connect and read timeouts from configuration. There are
  no defaults: a vendor without configured timeouts fails start-up.
- Vendor **SDKs** only when they do something we should not reimplement: Firebase Admin SDK
  for FCM (Google OAuth service-account flow). Razorpay, RazorpayX, Google Maps, Freshdesk and
  Supabase Storage are called over REST with our own typed records, which keeps timeouts,
  logging and tests under our control. Each SDK that is adopted is wrapped so no SDK type leaks
  outside `integrations`.
- Outbound requests and responses are **not logged** (ADR 0006). Logged: vendor, operation,
  status code, latency, our error code, correlation id.

### Resilience (Resilience4j, ADR 0001)

Per vendor and, where behaviour differs, per operation:

| Concern | Rule |
|---|---|
| Timeouts | HTTP connect/read timeouts on every client. Interactive calls use short timeouts; background jobs may use longer ones |
| Circuit breaker | One per vendor. When open, the port returns a typed "unavailable" result and the API answers 503 `SERVICE_UNAVAILABLE` |
| Bulkhead | Semaphore bulkhead per vendor so one slow vendor cannot exhaust request threads |
| Retry | **Only** for (a) reads, (b) calls the vendor makes idempotent with a key we supply, or (c) failures where the request provably did not reach the vendor (connection refused). Exponential backoff with jitter, small attempt count |
| No retry | Non-idempotent writes without a vendor idempotency key (for example creating a Razorpay order). Instead: record our intent first, call once, and let **reconciliation** settle an unknown outcome |
| Rate limits | Vendor 429 → typed result with `retryAfter`; background jobs back off, interactive calls fail fast |

Resilience4j metrics are bound to Micrometer.

### Unknown outcomes

A timeout on a money-moving call does **not** mean failure. The rule for every such operation:

1. Persist the intent with a unique reference (our id) **before** calling the vendor.
2. Pass that reference to the vendor (receipt, notes, reference id or idempotency header,
   whichever the vendor supports).
3. On timeout, mark the record `UNKNOWN`, never `FAILED`.
4. A reconciliation job queries the vendor by our reference and settles the state.

Vendor-specific support (for example RazorpayX's payout idempotency header) is verified
against current vendor documentation in the milestone that integrates the vendor.

### Error translation

```
vendor HTTP error / exception
  → integrations: VendorUnavailable | VendorRejected(code) | VendorRateLimited | VendorTimeout
  → feature adapter: domain result (e.g. PaymentGatewayResult.Declined) or application exception
  → shared.error: API error code (ADR 0005)
```

Vendor error messages and payloads never reach API responses or logs.

### Configuration and secrets

- One `@ConfigurationProperties` record per vendor, `@Validated`, bound from environment
  variables, failing fast at start-up when anything required is missing.
- **No URLs, keys or secrets in code or committed configuration** (standard 8). Committed
  profiles hold only non-secret, non-environment values.
- Secrets come from the hosting platform's secret store (U1). Live keys are refused outside
  production (for example a Razorpay key id must start with `rzp_test_` unless
  `APP_ENV=production`, per BDD feature 20).
- The Supabase **service role key** (needed for Storage administration) is the most powerful
  secret in the system. Only `integrations.supabase` reads it.

### Files (Supabase Storage)

The API never proxies file bytes. The backend issues short-lived **signed upload URLs** and
**signed download URLs** after checking authorization, validates type and size limits, and
records the object path against the owning entity. Buckets are private.

### Push notifications (FCM)

The client already has a stubbed "register push token" call
(`proxy-care-client/lib/core/notifications/push_notifications.dart`). Device tokens are stored
by the `notification` module; sends happen in event listeners (ADR 0008), never inside a
business transaction. Payloads carry ids and a type only, no health information.

### Testing integrations

- **WireMock** (version verified in Milestone 01, ADR 0001) stubs each vendor's HTTP API from
  fixtures copied from vendor documentation: success, each documented error, malformed bodies,
  timeouts (fixed delay), 429 and 5xx.
- Tests for resilience behaviour: circuit opens after the threshold, no retry on
  non-idempotent writes, `UNKNOWN` on timeout.
- Webhook signature tests use fixtures signed with test secrets, including the BDD's negative
  cases (wrong secret, modified body, re-serialised JSON, empty body).
- A separate, **manually triggered** Gradle task may call vendor sandboxes. It is never part of
  `./gradlew build` or CI.

## Alternatives considered

- **Vendor SDKs everywhere.** Rejected: hidden HTTP clients, default timeouts we do not
  control, transitive dependencies (some still on Jackson 2 or old OkHttp), harder to stub.
- **Spring Cloud OpenFeign / HTTP interface clients.** HTTP interfaces (`@HttpExchange`) over
  `RestClient` are acceptable inside a vendor package where they reduce boilerplate. Feign is
  not adopted (extra dependency, no gain over `RestClient`).
- **Spring Cloud Circuit Breaker.** Not needed; it is a facade over Resilience4j.

## Addendum (Milestone 02, 2026-11-18): behaviour fixed by `RestClientFactory`

Implementing the client base and its contract tests settled two details this ADR left open:

- **HTTP/1.1.** Clients use HTTP/1.1 explicitly. The JDK's HTTP/2 default negotiates over TLS
  (ALPN) in production but tries a cleartext upgrade (`h2c`) against local stubs. That upgrade
  failed on requests with a body, so tests wouldn't exercise production's protocol. Every vendor
  in scope supports HTTP/1.1.
- **Vendor responses tolerate unknown fields.** The application mapper rejects unknown properties
  in our own API's input (ADR 0005). Vendors add response fields without notice, so vendor
  clients read with a copy of the application mapper that ignores unknown properties. Everything
  else stays the same, including rejecting fractional values for integer amounts.

## Unresolved

- **U10**: Commercial API access for Uber (and Rapido, named in the PRD). Ride APIs for
  third-party booking normally need a business agreement; until access is confirmed the ride
  milestone cannot be scheduled with confidence.
- **U10**: Which HyperVerge products (Aadhaar/PAN verification, video KYC) are contracted.
