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
