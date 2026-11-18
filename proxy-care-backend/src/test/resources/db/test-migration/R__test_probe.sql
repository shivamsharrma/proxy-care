-- TEST-ONLY fixtures. Loaded only by the test profile (application-test.yml adds this
-- location); never part of src/main and never deployed. Runs as proxycare_migrator after the
-- versioned migrations, so the default privileges from the baseline apply.
--
-- They let the testing infrastructure exercise what feature tables rely on before any exists.
-- Like every table, they follow the schema rules in docs/DATABASE.md, including RLS.

-- Raw SQL fixture: constraints, transactions, money, UTC timestamps, PostGIS, concurrency.
create table if not exists proxycare.test_probe (
    id           uuid primary key,
    natural_key  text        not null unique,
    amount_paise bigint      not null check (amount_paise >= 0),
    state        text        not null default 'OPEN' check (state in ('OPEN', 'CLAIMED')),
    location     extensions.geography(Point, 4326),
    created_at   timestamptz not null
);

alter table proxycare.test_probe enable row level security;
drop policy if exists proxycare_app_all on proxycare.test_probe;
create policy proxycare_app_all on proxycare.test_probe
    for all to proxycare_app using (true) with check (true);

-- JPA fixture (support.persistence.ProbeEntity): BaseEntity columns, Money, soft delete.
create table if not exists proxycare.test_probe_entity (
    id           uuid primary key,
    version      bigint      not null,
    created_at   timestamptz not null,
    updated_at   timestamptz not null,
    name         text        not null,
    amount_paise bigint      not null check (amount_paise >= 0),
    deleted      boolean     not null default false
);

alter table proxycare.test_probe_entity enable row level security;
drop policy if exists proxycare_app_all on proxycare.test_probe_entity;
create policy proxycare_app_all on proxycare.test_probe_entity
    for all to proxycare_app using (true) with check (true);
