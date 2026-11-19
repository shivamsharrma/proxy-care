# Milestones

## M0 — Skeleton, build and CI   ✅ complete (2026-11-19)
Tests: 3/3 (new in this milestone: ApplicationContextTest, HealthEndpointTest, AppPropertiesTest)
CI: https://github.com/shivamsharrma/proxy-care/actions/runs/44587361677    Tag: none (branch-only, per user)    Commit: 0d23d91
Main-source class count: 3 (PermitAllSecurityConfig is temporary; M4 deletes it)
Assumptions to verify: the Supabase project runs Postgres 17 (test image postgis/postgis:17-3.5)
Added to LATER.md: none

## M1 — Test foundation   ✅ complete (2026-11-20)
Tests: 17/17 (new in this milestone: TestTokensTest ×4, MutableClockTest ×4, IntegrationTestIsolationTest ×3, SharedContainerTest ×2, AuthStubTest ×1; M0 tests migrated to IntegrationTest)
CI: https://github.com/shivamsharrma/proxy-care/actions/runs/44588895233    Tag: none (branch-only, per user)    Commit: 933c8c1
Main-source class count: 3 (unchanged; M1 is test code only)
Assumptions to verify: postgis/postgis pre-installs PostGIS in `public` of the test DB, unlike Supabase (`extensions`); M2's `create extension if not exists` is a no-op there.
Added to LATER.md: none

## M2 — Persistence foundation   ✅ complete (2026-11-20)
Tests: 27/27 (new in this milestone: MigrationTest ×2, RlsEnabledTest ×1, BaseEntityAuditingTest ×3, ProfilesConstraintTest ×2, TestDbProfileTest ×2)
CI: https://github.com/shivamsharrma/proxy-care/actions/runs/44590541901    Tag: none (branch-only, per user)    Commit: 3bd7d63
Main-source class count: 5 (ProxyCareApplication, AppProperties, AppConfig, BaseEntity, PermitAllSecurityConfig [temporary])
Assumptions to verify:
- The backend DB role on Supabase can run `create extension postgis with schema extensions` (or PostGIS is already enabled there).
- `flyway_schema_history` lives in `public` without RLS (excluded by the RLS check). On Supabase, revoke `anon`/`authenticated` access to it, or enable RLS on it.
- `statement_timeout = 5s` also applies to migrations; long data migrations must raise it with `SET LOCAL`.
Added to LATER.md: none

## M3 — Error handling, response format, request logging, masking   ✅ complete (2026-11-20)
Tests: 50/50 (new in this milestone: ErrorFormatTest ×7, RequestIdTest ×6, AccessLogTest ×3, MaskTest ×4, PaginationTest ×3)
CI: https://github.com/shivamsharrma/proxy-care/actions/runs/44591970665    Tag: none (branch-only, per user)    Commit: 541c1c4
Main-source class count: 11 (+ ErrorCode, AppException, GlobalExceptionHandler, RequestLoggingFilter, PageResponse, Mask)
Assumptions to verify: none
Known limitation: the 1 MB body limit reads Content-Length; chunked bodies must be limited at the load balancer/proxy.
Notes: added `IntegrationTest.bearer(UUID)` (one line) so every M3 test sends a token, as required for M4 forward compatibility.
Other 4xx raised by Spring MVC (e.g. 415, 406) keep their HTTP status and use code MALFORMED_REQUEST.
Added to LATER.md: none

## M4 — Authentication, authorization and /me   ✅ complete (2026-11-20)
Tests: 76/76 (new in this milestone: AuthenticationTest ×10, MeEndpointTest ×4, AuthorizationTest ×3, PublicEndpointsTest ×4, ProdProfileTest ×3, SupabaseJwtConverterTest ×2)
CI: https://github.com/shivamsharrma/proxy-care/actions/runs/44593599394    Tag: none (branch-only, per user)    Commit: 9f3f321
Main-source class count: 14 (+ SecurityConfig, SupabaseJwtConverter, CurrentUser, MeController; − PermitAllSecurityConfig)
Assumptions to verify:
- TODO(verify): the real Supabase project's signing algorithm (ES256 expected; RS256 also accepted).
- Supabase's `phone` claim is digits without "+" (e.g. 919876543210); /me masks whatever the claim holds.
Notes: ProdProfileTest boots the real app with the prod profile against the shared container (no second container);
the test JwtDecoder is a @Primary bean built by the same SecurityConfig.jwksDecoder(...) as prod.
Added to LATER.md: none

## M5 — Idempotency   ✅ complete (2026-11-20)
Tests: 86/86 (new in this milestone: IdempotencyTest ×7, IdempotencyConcurrencyTest ×2, IdempotencyCleanupTest ×1; RlsEnabledTest now covers idempotency_keys)
CI: https://github.com/shivamsharrma/proxy-care/actions/runs/44595282985    Tag: none (branch-only, per user)    Commit: 2affa99
Main-source class count: 15 (+ IdempotencyService)
Assumptions to verify: none
Known limitations (in README): JSON responses only, headers such as Location are not replayed; a rollback can't undo vendor calls.
Notes:
- The test profile sets lock-timeout=500ms for all tests (a per-class property would create a second context and container).
- Found while testing: Jackson 3 rejects JSON that omits a primitive record field (400 MALFORMED_REQUEST). Documented in the README.
- Added an index on idempotency_keys(created_at) for the daily cleanup.
Added to LATER.md: none
