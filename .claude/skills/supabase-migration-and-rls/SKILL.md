---
name: supabase-migration-and-rls
description: Write a Supabase Postgres migration with RLS policies and pgTAP tests for Proxy Care tables (bookings, payment requests, rides, caretakers). Use for any schema, policy, function or realtime publication change.
---

# Supabase migration and RLS

Rules: `.claude/rules/supabase-auth-rls.md`. For Postgres specifics also
load the `supabase:supabase-postgres-best-practices` skill if available.

## Steps
1. `supabase migration new <name>` → `supabase/migrations/<ts>_<name>.sql`.
   Never edit an applied migration.
2. In the same file:
   - table with `id uuid primary key default gen_random_uuid()`,
     `created_at/updated_at timestamptz`, money as `bigint` paise, status as
     text + check constraint (or enum) matching the API;
   - `alter table ... enable row level security;`
   - one policy per operation and role, e.g.
     `create policy "sponsor reads own bookings" on public.bookings for select to authenticated using (sponsor_id = (select auth.uid()));`
   - indexes on every column a policy or FK filters by;
   - add to `supabase_realtime` publication only if a screen needs live updates.
3. pgTAP test in `supabase/tests/<name>.test.sql`: owner can, other user
   cannot, unassigned caretaker cannot, anon cannot — for each operation.
4. Local check: `supabase db reset` then `supabase test db`.
5. Read-only check with the Supabase MCP: advisors show no new security or
   performance warnings (`get_advisors`).
6. Applying to staging/prod is a human step via CI — never from Claude.

## Never
- `using (true)` / `with check (true)` on user data.
- `security definer` without `set search_path = ''` and an `auth.uid()` check.
- Role checks against `user_metadata`.
