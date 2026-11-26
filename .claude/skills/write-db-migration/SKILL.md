---
name: write-db-migration
description: "Write a forward-only Flyway migration for proxy-care-backend's Supabase Postgres — tables, columns, constraints, indexes, enums, RLS enabled with no policies — and its constraint tests. Use for any schema change."
---

# Write a database migration

The rules (Flyway owns the schema, forward-only, RLS on with no policies):
`.claude/rules/auth-and-rls.md` → Schema and RLS. For Postgres specifics
also load `supabase:supabase-postgres-best-practices` if available.

## Steps
1. List `proxy-care-backend/src/main/resources/db/migration/` and add
   `V<n+1>__<snake_name>.sql`.
2. In that file:
   - columns matching `BaseEntity`: `id uuid primary key`,
     `created_at timestamptz not null`, `updated_at timestamptz not null`,
     `version bigint not null` (ids from Supabase reference `auth.users (id)`
     instead, like `profiles`, which still has `created_at` and `version`);
     adding `version` to an existing table: `bigint not null default 0`;
   - `created_at` / `updated_at` are written by JPA auditing; don't rely on a
     column default for them;
   - money as `bigint` paise; enums and statuses as plain `text` (`text[]`
     for a set) holding the Java enum names; never `create type ... as enum`
     (user decision 2026-11-26, migration `V10__enums_as_text.sql`);
   - Java enums mapped with `@Enumerated(STRING)` are stored as their names
     (`EN`, not `en`); changing an existing column's values to names needs an
     `update ... set col = upper(col)` and a new default, like
     `V4__profiles_preferred_language_enum_names.sql`;
   - foreign keys with an explicit `on delete`; an index on every FK and on
     the owner columns services filter by (`sponsor_id`, `caretaker_id`);
   - `alter table <t> enable row level security;` with the deny-all comment
     used in `V2__profiles.sql`.
3. Tests (`testing.md` → Server):
   - `RlsEnabledTest` and `ddl-auto: validate` already cover RLS and the
     entity mapping.
   - Add `<Table>ConstraintTest` in `common/persistence` per check / unique /
     FK rule, expecting `DataIntegrityViolationException`, like
     `ProfilesConstraintTest`; add a `TestDb` insert helper if needed.
4. Server full gate (`testing.md` → Commands) is green.
5. Read-only Supabase MCP: `get_advisors` shows no new security or
   performance warnings. Applying to staging/prod is a human/CI step.

## Also never
- Functions in `public`, or `security definer` without `set search_path = ''`.
- Realtime publications (open question in `auth-and-rls.md`).
- Seed or test data in production migrations.
