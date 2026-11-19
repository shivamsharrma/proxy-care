-- Local only: stands in for Supabase's auth schema, which plain Postgres lacks
-- (profiles references auth.users). Not needed with `supabase start`.
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key);
