-- Allowed values are validated in request DTOs, not by DB checks; the languages (en, hi) live there.
-- V2 declared the check inline, so Postgres named it profiles_preferred_language_check.
alter table profiles drop constraint profiles_preferred_language_check;
