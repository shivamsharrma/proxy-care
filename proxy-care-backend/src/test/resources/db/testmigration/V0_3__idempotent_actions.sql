-- Rows written by the idempotent probe action; rolled back with its transaction.
create table test_support.idempotent_actions (
    id   uuid primary key default gen_random_uuid(),
    name text
);
