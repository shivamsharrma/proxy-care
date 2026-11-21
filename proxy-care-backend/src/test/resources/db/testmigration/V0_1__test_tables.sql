-- Backs the test-only AuditedThing entity (BaseEntityAuditingTest).
create table test_support.audited_things (
    id         uuid primary key,
    name       text,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    version    bigint not null
);
