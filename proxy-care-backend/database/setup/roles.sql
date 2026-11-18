-- Proxy Care database setup: roles, schema ownership and PostGIS (docs/DATABASE.md).
--
-- Run once per database by an administrator, BEFORE the first Flyway migration:
--   * Supabase: SQL editor as `postgres`, then set passwords with psql's \password
--     (never put passwords in this file or in a SQL statement that may be logged).
--   * Local Docker and tests: docker/postgres/init/20-proxycare.sh runs it automatically.
--
-- Idempotent: safe to run again.
--
-- Roles (ADR 0003):
--   proxycare_migrator  owns schema proxycare; used only by Flyway.
--   proxycare_app       the running application: data reads and writes, no DDL.
-- Neither is a superuser, `postgres`, or Supabase's service_role.

-- PostGIS lives in Supabase's `extensions` schema (already present on Supabase).
create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

do $$
begin
  if not exists (select from pg_catalog.pg_roles where rolname = 'proxycare_migrator') then
    create role proxycare_migrator login;
  end if;
  if not exists (select from pg_catalog.pg_roles where rolname = 'proxycare_app') then
    create role proxycare_app login;
  end if;
end
$$;

alter role proxycare_migrator nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
alter role proxycare_app nosuperuser nocreatedb nocreaterole noreplication nobypassrls;

alter role proxycare_migrator set search_path = proxycare, extensions;
alter role proxycare_app set search_path = proxycare, extensions;

-- On Supabase `postgres` is not a superuser: it must be a member of a role to hand it ownership.
grant proxycare_migrator to current_user;

create schema if not exists proxycare authorization proxycare_migrator;
alter schema proxycare owner to proxycare_migrator;

-- Nobody but the two roles above may use the schema. In particular the Supabase API roles used by
-- mobile clients (anon, authenticated) get nothing; only an approved, explicit grant may change that.
revoke all on schema proxycare from public;
do $$
declare
  api_role text;
begin
  foreach api_role in array array['anon', 'authenticated', 'service_role'] loop
    if exists (select from pg_catalog.pg_roles where rolname = api_role) then
      execute format('revoke all on schema proxycare from %I', api_role);
      execute format('revoke all on all tables in schema proxycare from %I', api_role);
      execute format('revoke all on all sequences in schema proxycare from %I', api_role);
    end if;
  end loop;
end
$$;

grant usage on schema extensions to proxycare_migrator, proxycare_app;
