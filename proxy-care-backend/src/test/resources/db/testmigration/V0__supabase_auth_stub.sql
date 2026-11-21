-- Stands in for Supabase's own auth schema, which a plain Postgres container lacks.
create schema if not exists auth;
create table auth.users (id uuid primary key);

-- Test-only tables live here, never in public, so the RLS check covers only real app tables.
create schema if not exists test_support;
