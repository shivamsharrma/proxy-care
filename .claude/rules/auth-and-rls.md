---
paths:
  - "proxy-care-client/lib/core/auth/**"
  - "proxy-care-backend/**/security/**"
  - "proxy-care-backend/src/main/resources/db/migration/**"
  - "proxy-care-backend/src/test/resources/db/**"
---
# Supabase auth and RLS

Supabase provides Postgres, phone-OTP sign-in and storage. The backend is the
only writer of business data (`proxy-care-backend/ARCHITECTURE.md` → Decisions).

## Keys
Which keys are allowed where: `security.md` → Client keys, Database. Supabase
specifics:
- Backend needs only `SUPABASE_URL` (issuer + JWKS) and its dedicated
  Postgres role over the session pooler (`DB_URL`, `DB_USER`, `DB_PASSWORD`);
  it never forwards any key to a client.

## Auth (backend)
- Stateless resource server: each request's Supabase access token is verified
  against the project JWKS (ES256 or RS256) in `common/security/jwt`
  (issuer, audience, expiry). The backend never sees OTPs or passwords.
- Roles come from our `profiles` table (`app_role[]`) via `IUserRoleProvider`
  on every request, not from token claims, so role changes apply on the next
  call. `Role` names match the `app_role` enum: never rename one.
- A signed-in user without a `profiles` row has no roles
  (`PROFILE_NOT_FOUND` → the app shows onboarding).

## Auth (client)
- Session persisted only via `SecureSupabaseLocalStorage` (see
  `proxy-care-client/SECURITY.md`, `AUTHENTICATION.md`). PKCE flow.
- Never use `user_metadata` for anything trusted (users can edit it).
- **Open question:** the client docs read roles from `app_metadata` and use
  Supabase realtime under RLS, but the backend owns roles (`profiles`) and
  RLS is deny-all. Ask before building on either.

## Schema and RLS
- Flyway in `proxy-care-backend` owns the schema:
  `src/main/resources/db/migration/V<n>__<name>.sql`, forward-only. No
  Supabase CLI migrations.
- **Every table has RLS enabled with no policies** in the migration that
  creates it — deny-all for `anon` and `authenticated`, so the apps can't
  bypass the API. Adding a policy is an architecture decision, not a
  migration detail. `RlsEnabledTest` fails the build otherwise.
- Ownership is enforced in the backend service (`backend-code.md` →
  Identity and authorization), mirroring the `*_access_control.feature` specs.
- Tables referencing `auth.users` work locally through the stub
  (`docker/auth-stub.sql`, `db/testmigration/V0__supabase_auth_stub.sql`).
  Test-only tables go in the `test_support` schema.

## Checks
- Supabase advisors (`get_advisors` via the read-only Supabase MCP) show no
  security warnings before a migration PR merges.
