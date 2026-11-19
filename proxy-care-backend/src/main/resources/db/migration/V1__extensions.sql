-- Supabase convention: extensions live in their own schema, not in public.
-- gen_random_uuid() is built into Postgres 13+, so pgcrypto is not needed.
create schema if not exists extensions;
create extension if not exists postgis with schema extensions;
