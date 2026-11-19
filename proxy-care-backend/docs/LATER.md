# Deferred

Things we decided not to build yet, and the trigger for adding each.

| Deferred | Add it when |
|---|---|
| Caffeine cache for the role lookup | The profile lookup shows up in latency metrics |
| ShedLock | You run 2+ instances **and** a job must not run twice |
| Transactional outbox | Lost push notifications or realtime events become a real problem |
| Resilience4j (circuit breaker/retry) | A vendor's outages start cascading into our API |
| Rate limiting (Bucket4j or gateway) | Abuse shows up, or before public launch, at the load balancer |
| OpenTelemetry tracing | Multiple services exist, or requestId isn't enough to debug |
| Server-side i18n | The server must send localized text (SMS, PDFs, push copy) |
| ETag / If-Match | Two clients really edit the same resource concurrently |
| Modulith / ArchUnit | More than about 5 developers, or module boundaries start rotting |
| Vendor ports with fake adapters | When writing that feature, and only for the vendor being tested |

## Skipped along the way

| Item | Why it was skipped / when to revisit |
|---|---|
| `serviceRoleKey` in `AppProperties` | Highly privileged and unused. Add it with the Storage (signed URLs) feature. |
| RLS on `flyway_schema_history` | Excluded from the RLS check by design. On Supabase, revoke `anon`/`authenticated` access to it (or enable RLS) when setting up the DB role. |
| Body limit for chunked requests | `RequestLoggingFilter` only checks `Content-Length`. Enforce a body limit at the load balancer/proxy before launch. |
| Webhook event processing | `webhook_events` only records events. The payments feature adds handlers and sets `processed_at`/`error`. |
| Replaying non-JSON idempotent responses and headers (`Location`) | Not needed by any endpoint yet. |
| Role-lookup and `/me` combined into one query | Two small queries per `/me` call today; merge if it matters. |
