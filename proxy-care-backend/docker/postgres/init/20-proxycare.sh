#!/usr/bin/env bash
# Local and test databases only (never Supabase). Runs once, when the container's data
# directory is first created, after the PostGIS image's own init script.
#
# 1. Makes the PostGIS image look like Supabase: PostGIS in the `extensions` schema and the
#    Supabase API roles (anon, authenticated, service_role) present.
# 2. Applies database/setup/roles.sql, the same script production uses.
# 3. Sets the role passwords from the container environment.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
-- The PostGIS image installs these in `public`; Supabase installs PostGIS in `extensions`.
drop extension if exists postgis_tiger_geocoder;
drop extension if exists postgis_topology;
drop extension if exists fuzzystrmatch;
drop extension if exists postgis;
drop schema if exists tiger, tiger_data, topology cascade;

do $$
begin
  if not exists (select from pg_catalog.pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select from pg_catalog.pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select from pg_catalog.pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end
$$;
SQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --file /proxycare-setup/roles.sql

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v migrator_password="$PROXYCARE_DB_MIGRATOR_PASSWORD" \
  -v app_password="$PROXYCARE_DB_PASSWORD" <<'SQL'
alter role proxycare_migrator password :'migrator_password';
alter role proxycare_app password :'app_password';
SQL
