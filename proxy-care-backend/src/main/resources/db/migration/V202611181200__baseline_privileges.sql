-- Baseline for schema proxycare (docs/DATABASE.md). Runs as proxycare_migrator, the schema
-- owner. Requires database/setup/roles.sql to have run first (roles, schema, PostGIS).

-- Declares the extensions the schema depends on. They are installed by the setup script
-- (installing PostGIS needs administrator rights); here this is a no-op that fails loudly if
-- the setup step was skipped.
create extension if not exists postgis with schema extensions;

-- Only the application role may use the schema; the Supabase API roles get nothing.
revoke all on schema proxycare from public;
grant usage on schema proxycare to proxycare_app;

-- Every table and sequence the migrator creates from now on is readable and writable by the
-- application, and nothing more: no DDL, TRUNCATE, REFERENCES or TRIGGER.
-- Flyway's own history table was created before this ran, so the application cannot touch it.
alter default privileges in schema proxycare
  grant select, insert, update, delete on tables to proxycare_app;
alter default privileges in schema proxycare
  grant usage, select on sequences to proxycare_app;
alter default privileges in schema proxycare
  revoke execute on functions from public;
