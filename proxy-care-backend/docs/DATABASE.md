# Database

How the backend uses Supabase PostgreSQL: connections, roles and privileges, migrations, and
the conventions every table and entity follows. Decisions are in
[ADR 0003](adr/0003-database-and-migrations.md).

## Connections

The application connects with the PostgreSQL JDBC driver through HikariCP, as `proxycare_app`.
It never connects as `postgres`, as a superuser, or with Supabase's `service_role` key.

### Supabase connection modes

| Mode | Host:port | Use it? |
|---|---|---|
| Direct | `db.<ref>.supabase.co:5432` (IPv6, or IPv4 with the add-on) | **Yes**, when the host has IPv6 or the IPv4 add-on |
| Supavisor session mode | `<region>.pooler.supabase.com:5432` | **Yes**, from IPv4-only hosts |
| Supavisor transaction mode | `<region>.pooler.supabase.com:6543` | **No**. Refused at start-up |
| Dedicated pooler (PgBouncer, transaction mode) | `db.<ref>.supabase.co:6543` | **No**. Refused at start-up |

Only the URL changes between direct and session mode. Example:

```
PROXYCARE_DB_URL=jdbc:postgresql://db.<ref>.supabase.co:5432/postgres?sslmode=verify-full&sslrootcert=/etc/proxycare/supabase-ca.crt
```

In session mode the username takes Supavisor's form: `proxycare_app.<project-ref>`.

Staging and production refuse to start unless the URL is a non-local `jdbc:postgresql://` URL
with `sslmode=verify-full` that doesn't use port 6543 (`DeploymentConfigurationValidator`).
Download the Supabase CA certificate from the project's database settings, and mount it where
`sslrootcert` points.

### Why not transaction-mode pooling

In transaction mode a client gets a different server connection for each transaction. The
backend relies on things that only work when one client keeps one server session:

- **Session limits** (below) are set once per connection with `SET`. They would apply to someone
  else's session, or vanish.
- **Prepared statements**: the shared Supavisor pooler doesn't support them in transaction mode.
- **Advisory locks** (ShedLock), `LISTEN`/`NOTIFY`, and temporary tables are session-scoped.
- `SET LOCAL` inside a transaction is safe, but nothing outside a transaction is.

If connection count ever becomes the bottleneck, the dedicated pooler can be reconsidered.
That would require disabling server-side prepared statements (`prepareThreshold=0`), moving the
session limits to role-level settings, and re-testing ShedLock. It's a new ADR, not a
configuration change.

### Pool

All settings are explicit in `application.yml` (`spring.datasource.hikari.*`):

| Setting | Value | Why |
|---|---|---|
| `maximum-pool-size` | 10 | Per instance. Total across instances must stay below the Supabase compute tier's connection limit, with headroom for migrations and operators (open decision U2) |
| `minimum-idle` | 2 | |
| `connection-timeout` | 5 s | Waiting longer for a connection only queues more work |
| `max-lifetime` | 25 min | Below server and pooler idle cut-offs, so the pool retires connections first |
| `keepalive-time` | 5 min | Keeps idle connections alive through network middleboxes |
| `ApplicationName` | `proxy-care-backend` | Identifies the application in `pg_stat_activity` |

### Session limits

Every pooled connection runs this on creation (`DatabaseSessionSettings`, configured under
`proxycare.persistence.*`):

| Setting | Default | Protects against |
|---|---|---|
| `statement_timeout` | 30 s | A runaway query holding a connection |
| `lock_timeout` | 10 s | Waiting forever behind a lock |
| `idle_in_transaction_session_timeout` | 60 s | A transaction left open, holding locks |

Values must be positive (zero means "no limit" to PostgreSQL). The SQL is built from validated
durations, never from raw configuration text. Spring transactions also time out after 30 s
(`spring.transaction.default-timeout`).

### Health

Readiness (`/actuator/health/readiness`, on the management port in deployed environments)
includes the database check. Liveness doesn't (ADR 0006).

## Roles and privileges

| Role | Who uses it | Privileges |
|---|---|---|
| `proxycare_migrator` | Flyway only | Owns schema `proxycare` and every object in it |
| `proxycare_app` | The running application | `USAGE` on the schema; `SELECT, INSERT, UPDATE, DELETE` on tables; `USAGE, SELECT` on sequences. No DDL, `TRUNCATE`, `REFERENCES` or `TRIGGER`; no access to Flyway's history |
| `anon`, `authenticated` (Supabase API, mobile clients) | — | **Nothing** in `proxycare` |
| `service_role` | — | Nothing in `proxycare` (it bypasses RLS, so schema privileges are what keeps it out) |

Defence in depth:

1. **The schema isn't exposed.** `proxycare` must not be added to the Supabase Data API's
   exposed schemas.
2. **No grants** to `PUBLIC` or the API roles on the schema or its objects.
3. **Row Level Security** is enabled on every table, with exactly one policy:
   `proxycare_app_all ... to proxycare_app using (true) with check (true)`. Any other role
   that somehow gets a grant still sees no rows. Which rows a *user* may see is decided in the
   application layer (ADR 0004), not in RLS.

Mobile clients get access to a table only through a separately approved decision: a new ADR
and an explicit policy.

`DatabaseSecurityTest` enforces all of this on every build, for every table: ownership, RLS and
the policy, the absence of API-role privileges (checked in the catalog and by actually
connecting as `anon` and `authenticated`), and what the application role can't do.

### Setting up a Supabase project (runbook)

Once per environment, by an administrator, before the first deployment:

1. Make sure `proxycare` is **not** listed under Settings → API → Exposed schemas.
2. Open the SQL editor (role `postgres`) and run [`database/setup/roles.sql`](../database/setup/roles.sql).
   It's idempotent. It installs PostGIS in `extensions`, creates the two roles, creates the
   schema owned by the migrator, and revokes access from the API roles.
3. Set the passwords from a psql session (they're sent hashed and never appear in logs):
   `\password proxycare_migrator` and `\password proxycare_app`. Store them in the
   platform's secret store.
4. Run the migrations as `proxycare_migrator` (deployment pipeline, see "Migrations").
5. Give the application `proxycare_app`'s credentials (`PROXYCARE_DB_USERNAME`,
   `PROXYCARE_DB_PASSWORD`, `PROXYCARE_DB_URL`).

Local and test databases run the same script automatically
(`docker/postgres/init/20-proxycare.sh`). That script also makes the PostGIS image look like
Supabase: PostGIS in `extensions`, and the API roles present.

## Migrations

- **Flyway owns the schema.** Hibernate only validates (`ddl-auto=validate`). `create`,
  `create-drop` and `update` are refused at start-up in every environment.
- **Location and naming:** `src/main/resources/db/migration/V<yyyyMMddHHmm>__<what>.sql`.
- **Forward-only.** A migration that has run anywhere is never edited: Flyway's checksum
  validation fails the build. To change something, add a new migration. There are no undo
  scripts.
- **Expand / contract** for live tables (ADR 0003). `CREATE INDEX CONCURRENTLY` goes in its own
  migration with `-- flyway:executeInTransaction=false`.
- **Extensions** are installed by the setup script, because that needs administrator rights. The
  baseline migration declares them with `create extension if not exists`, which fails loudly if
  setup was skipped. Flyway logs PostgreSQL's "already exists, skipping" notice as a warning;
  that's expected.
- **Who runs them:**
  - Tests and local: at start-up, as `proxycare_migrator` (`spring.flyway.user`).
  - Staging and production: Flyway is disabled at start-up and must run as a separate step
    before the new version starts, as `proxycare_migrator`. That step is part of the deployment
    milestone (hosting is open decision U1). Until then, deployed environments can't be
    migrated automatically.

### Checklist for a new table

```sql
create table proxycare.<name> (
    id          uuid primary key,              -- BaseEntity: UUIDv7 from Hibernate
    version     bigint      not null,          -- optimistic locking
    created_at  timestamptz not null,          -- UTC, from the application clock
    updated_at  timestamptz not null,
    -- money:     <x>_paise bigint not null check (<x>_paise >= 0)   where negatives are invalid
    -- enums:     text not null check (<col> in ('A', 'B'))
    -- locations: extensions.geography(Point, 4326) with a GiST index
    -- soft delete, only where needed: deleted boolean not null default false
    ...
);

alter table proxycare.<name> enable row level security;
create policy proxycare_app_all on proxycare.<name>
    for all to proxycare_app using (true) with check (true);
```

Grants need nothing extra: the baseline's default privileges give `proxycare_app` data access
to every table the migrator creates. Forgetting RLS or the policy fails `DatabaseSecurityTest`.

## Entities

- Entities live in a module's `infrastructure` package, extend
  [`BaseEntity`](../src/main/java/in/proxycare/shared/persistence/BaseEntity.java), and never
  leave the module or appear in an API (ArchitectureTest).
- **Ids:** UUID version 7 from Hibernate's `@UuidGenerator(style = VERSION_7)`. They're
  time-ordered, so new rows append to the index, and they're assigned on persist. Equality is by
  id once assigned.
- **Auditing:** `created_at` and `updated_at` come from the application `Clock` (Spring Data
  auditing with a clock-backed `DateTimeProvider`), truncated to microseconds to match
  `timestamptz`.
- **Optimistic locking:** `@Version`. A stale update throws
  `ObjectOptimisticLockingFailureException`, which will map to 409 `CONFLICT` (ADR 0005).
- **Soft delete:** only where a feature needs deleted rows kept. Use Hibernate's
  `@SoftDelete` (boolean column `deleted`): deleting sets the flag, and queries exclude flagged
  rows. There is no generic base class for it. Who deleted a row, and when, belongs in that
  module's audit trail.
- **Repositories:** Spring Data interfaces per aggregate. There is no generic repository layer.
- **Money:** a `Money` attribute maps to a `bigint` paise column automatically
  (`MoneyConverter`).

## Money

[`Money`](../src/main/java/in/proxycare/shared/money/Money.java) is an immutable, INR-only
amount of paise held in a `long`.

- `plus`, `minus` and `times(long)` are exact, and throw on overflow instead of wrapping.
- `times(BigDecimal, RoundingMode)` rounds only as instructed. `UNNECESSARY` asserts the
  result is exact.
- `allocate(n)` and `allocate(ratios...)` split an amount with the largest-remainder method.
  The shares always add up exactly to the original amount.
- `format()` produces `₹1,23,456.78`: Indian digit grouping, locale-independent. It's also
  `toString()`.
- Amounts may be negative. Whether a negative amount is allowed is the caller's business rule.
- There's no `float` or `double` anywhere money is handled (ArchitectureTest).

## Time

- **Persist and exchange instants in UTC.** The JVM, JDBC session, Hibernate and Jackson are all
  set to UTC.
- **The business time zone is `Asia/Kolkata`.** Dates and wall-clock times that people choose or
  see (a visit date, a pickup time) are converted with
  [`BusinessTime`](../src/main/java/in/proxycare/shared/time/BusinessTime.java), for example
  "today in India" or "2 November, 10:00 in India → `2026-11-02T04:30:00Z`".
- **The current time comes only from the injected `Clock`.** `Instant.now()`, `LocalDateTime.now()`,
  other `now()` calls, the system clocks and `ZoneId.systemDefault()` are forbidden outside
  `shared.time` (ArchitectureTest).

## Tests

Database tests run against the real PostGIS image, prepared by the same setup script
(docs/TESTING.md). Flyway connects as the migrator and the application as `proxycare_app`, so
grant mistakes fail tests. No Supabase project is needed.
