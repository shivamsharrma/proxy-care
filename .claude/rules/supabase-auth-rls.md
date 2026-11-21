---
paths:
  - "supabase/**"
  - "proxy-care-client/lib/core/auth/**"
  - "proxy-care-server/**/security/**"
  - "proxy-care-server/**/identity/**"
---
# Supabase auth and RLS

## Keys
- Client: publishable/anon key + project URL only (`config/env/*.json`).
- Server: verifies Supabase JWTs via the project JWKS (asymmetric signing);
  `service_role` key only in server secrets, used for admin tasks, never
  forwarded to clients.

## Auth (client)
- Session persisted only via `SecureSupabaseLocalStorage` (see
  `proxy-care-client/SECURITY.md`, `AUTHENTICATION.md`). PKCE flow.
- Roles (user / caretaker / admin) come from server-controlled
  `app_metadata`, never `user_metadata` (users can edit that).

## Schema and RLS
- Migrations in `supabase/migrations/<timestamp>_<name>.sql`, created with
  `supabase migration new`. Never edit an applied migration — add a new one.
- **Every table in an exposed schema has RLS enabled** in the same migration
  that creates it, with explicit policies per operation (select/insert/
  update/delete) and role (`authenticated`). No `using (true)` on user data.
- Use `(select auth.uid())` in policies (evaluated once), index the columns
  policies filter on (`sponsor_id`, `caretaker_id`).
- Ownership: a user sees bookings they sponsor; a caretaker sees bookings
  assigned to them; nobody else. Mirror the `*_access_control.feature` specs.
- `security definer` functions: set `search_path = ''`, live in a
  non-exposed schema, and re-check `auth.uid()`.
- Realtime subscriptions rely on the same RLS — verify a non-owner receives nothing.

## Tests
- pgTAP tests per policy: owner allowed, other user denied, anon denied,
  caretaker unassigned denied.
- Advisors (`get_advisors` via Supabase MCP, read-only) must show no
  security warnings before a migration PR merges.
