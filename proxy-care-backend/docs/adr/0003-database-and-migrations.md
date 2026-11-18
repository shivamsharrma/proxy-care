# ADR 0003: Database, connections and migrations

- Status: Accepted (connection mode depends on unresolved hosting decision U1)
- Date: 2026-11-18

## Context

- The database is Supabase PostgreSQL with PostGIS (needed for "nearby caretakers" and live
  location).
- Supabase also runs PostgREST (the "Data API"), which exposes the `public` schema to anyone
  holding the project's publishable key. Supabase Auth owns the `auth` schema.
- The Flutter client talks to Supabase **only** for authentication. All business data goes
  through this backend.
- Supabase connection options (supabase.com docs, checked 2026-11-18):
  - **Direct**: `db.<ref>.supabase.co:5432`. IPv6, or IPv4 with the paid IPv4 add-on. No pooler
    in the path. Recommended for long-lived servers.
  - **Shared pooler, session mode** (Supavisor): port 5432, IPv4 on every plan. The documented
    alternative for IPv4-only networks.
  - **Shared pooler, transaction mode**: port 6543. Does **not** support prepared statements,
    session state or cursors held across transactions. Intended for serverless.
  - **Dedicated pooler** (PgBouncer, Pro plan and above): transaction mode; supports prepared
    statements on PgBouncer 1.21+.
- No schema, migrations or Supabase CLI configuration exist in the repository today.

## Decision

### Schema ownership

1. All backend tables live in a dedicated schema, **`proxycare`**, that is **not** listed in
   the Data API's exposed schemas. Nothing is created in `public`.
2. **Row Level Security is enabled on every `proxycare` table**, with exactly one permissive
   policy, `FOR ALL TO proxycare_app USING (true) WITH CHECK (true)`. PostgREST roles (`anon`,
   `authenticated`) have no policy and no grants, so they are denied. This is defence in depth
   in case the schema is ever exposed by mistake. Authorization of *which rows a user may see*
   stays in the application layer (ADR 0004), not in RLS. A migration test asserts that every
   table in `proxycare` has RLS enabled and only that policy.
3. **PostGIS** is enabled through Supabase's `extensions` schema (Supabase's convention).
   Spatial columns use `extensions.geography(Point, 4326)`.
4. The backend **never writes** to `auth`, `storage` or other Supabase-managed schemas.
   Account rows store the Supabase user id (`uuid`) **without a foreign key** to `auth.users`:
   that table's lifecycle belongs to Supabase, and a cross-owner FK couples our migrations to
   Supabase upgrades. The `identity` module reconciles deletions (a later milestone).

### Database roles

| Role | Used by | Privileges |
|---|---|---|
| `proxycare_migrator` | Flyway only | Owns schema `proxycare`; DDL |
| `proxycare_app` | Running application | `USAGE` on `proxycare`; `SELECT/INSERT/UPDATE/DELETE` on its tables and sequences; no DDL; no `BYPASSRLS` (row access comes from the `proxycare_app` policy above) |

- Neither is `postgres`, `service_role` or a superuser.
- `proxycare_app` gets role-level safety settings:
  `statement_timeout`, `idle_in_transaction_session_timeout`, `lock_timeout`.
  Values are set in a migration and reviewed with the first load test.
- The roles and their passwords are created once per environment by an operator runbook
  (Milestone 03), not by application migrations. Passwords live in the secret store, never in
  the repository.

### Migrations (Flyway)

- **Flyway owns the `proxycare` schema.** Hibernate runs with `ddl-auto=validate`; it never
  creates or alters tables. The Supabase CLI is not used for this schema.
- Location: `src/main/resources/db/migration`. Naming:
  `V<yyyyMMddHHmm>__<snake_case_description>.sql`, a timestamp so parallel branches do not
  collide on version numbers. `outOfOrder=false` in all deployed environments.
- **Forward-only.** An applied migration is never edited (Flyway checksum validation fails
  the build). Fixes are new migrations. No `undo` scripts.
- **Expand / contract** for anything that touches a live table: add new structure, deploy code
  that writes both, backfill, switch reads, then remove the old structure in a later release.
- Long or locking operations (`CREATE INDEX` on large tables) use `CONCURRENTLY` in their own
  non-transactional migration (Flyway script config `executeInTransaction=false`).
- **Where migrations run:**
  - Tests and local development: at application start-up, with a single local role.
  - Staging and production: as a **separate deployment step** before the new version starts,
    with `proxycare_migrator` credentials. The application starts with
    `spring.flyway.enabled=false` and Hibernate `validate`, so a schema/code mismatch fails at
    start-up instead of at the first request.
- Every migration is exercised by the Testcontainers suite on each CI run.

### Persistence technology

- **Spring Data JPA (Hibernate 7)** for aggregates that are loaded, changed and saved as a unit.
  Entities live in `infrastructure` and are mapped to/from domain objects. Entities never leave
  the module and never appear in an API.
- **`JdbcClient`** for read models, reports, bulk updates, `FOR UPDATE SKIP LOCKED` queues and
  PostGIS queries where SQL is clearer than JPQL.
- All SQL is parameterized. No string concatenation of values into SQL (ArchUnit cannot catch
  this fully; it is a code-review item, plus a test for each repository).
- `spring.jpa.open-in-view=false`.
- **Concurrency**: optimistic locking (`@Version`) on every mutable aggregate. Pessimistic
  row locks only in named places, e.g. the dispatch "first caretaker to accept" decision, which
  will be an atomic conditional `UPDATE … WHERE state = 'WAITING'` (Milestone for dispatch).
- **Database constraints are the last line of defence** for business uniqueness (for example
  one `RIDE_TO_HOSPITAL` payment request per ride) and for non-negative money
  (`CHECK (amount_paise >= 0)`).

### Types

| Concept | Column type |
|---|---|
| Identifiers | `uuid`, generated by the application (UUIDv7 preferred for index locality; generator chosen and tested in Milestone 03) |
| Instants | `timestamptz`, always UTC. JDBC `hibernate.jdbc.time_zone=UTC`; JVM `-Duser.timezone=UTC` |
| Money | `bigint` paise + `CHECK (>= 0)` where negatives are invalid. Currency is INR only; no currency column until a second currency is specified |
| Enumerations | `text` + `CHECK (col IN (...))`, not PostgreSQL `ENUM` (cheaper to evolve under expand/contract) |
| Locations | `extensions.geography(Point, 4326)` with a GiST index |
| Vendor payloads | `jsonb` |

### Connections

- Driver: PostgreSQL JDBC 42.7.x with `sslmode=verify-full` and the Supabase CA certificate
  supplied through configuration.
- Pool: HikariCP, all values explicit in configuration: `maximumPoolSize`, `minimumIdle`,
  `connectionTimeout`, `maxLifetime` (shorter than any server/pooler idle cut-off),
  `keepaliveTime`, `leakDetectionThreshold` in non-production. Starting size 10 per instance;
  total across instances must stay below the Supabase compute tier's connection limit with
  headroom for Flyway and operators (sized when U2 is resolved).
- **Connection mode, by environment:**
  - Hosting with IPv6 egress, or the IPv4 add-on: **direct connection**.
  - IPv4-only hosting without the add-on: **shared pooler in session mode** (port 5432).
  - **Never the shared transaction-mode pooler (6543)**: we rely on prepared statements,
    session time zone and `SKIP LOCKED` queues inside transactions.
  - The dedicated transaction-mode pooler is a later option if connection count becomes the
    bottleneck; it requires re-testing prepared statements and advisory locks (ShedLock).

### Local development and tests

- Tests use **Testcontainers** with the `postgis/postgis` image at the **same PostgreSQL major
  version as the Supabase project** (U12) and run every Flyway migration.
- A test-only migration (outside `db/migration`) creates the `extensions` schema and the two
  roles so tests exercise the real privilege model.
- Local runs use the same container through Spring Boot's Testcontainers dev-time support, so
  developers do not need a Supabase project to start the backend.

## Addendum (Milestone 03, 2026-11-18): as implemented

Implementation settled these details. The working guide is [DATABASE.md](../DATABASE.md).

- **Setup script instead of a runbook only.** Roles, schema ownership and PostGIS are in
  `database/setup/roles.sql`. The same file runs in the local Docker database, in the test
  container, and in the Supabase SQL editor, so production setup is exercised by every test run.
  Passwords are never in it.
- **Flyway doesn't create the schema** (`create-schemas=false`); the setup script does, with
  the migrator as owner.
- **Grants through default privileges** in the baseline migration: every table the migrator
  creates is automatically readable and writable by `proxycare_app`, and nothing more. Flyway's
  history table predates them, so the application can't modify it.
- **Session limits on the client side.** `statement_timeout`, `lock_timeout` and
  `idle_in_transaction_session_timeout` are applied per pooled connection from validated
  configuration (`proxycare.persistence.*`), not only as role defaults. That makes them
  testable and independent of an operator remembering `ALTER ROLE`. This relies on session
  continuity, which is one more reason transaction-mode pooling stays ruled out. Port 6543 is
  now refused at start-up.
- **UUIDv7 from Hibernate 7.4** (`@UuidGenerator(style = VERSION_7)`), which uses the system clock
  for the id's timestamp. Ids aren't business time, so the injected clock isn't needed there.
- **Tests use the real privilege model.** Flyway connects as `proxycare_migrator` and the
  application as `proxycare_app`; only test infrastructure uses the superuser.

## Alternatives considered

- **`public` schema.** Rejected: reachable through PostgREST with the publishable key unless
  every table has correct RLS policies; one mistake leaks data.
- **Supabase CLI migrations.** Rejected for `proxycare`: the backend must own and validate its
  schema; two migration tools on one schema drift. Supabase CLI may still manage Supabase
  configuration (auth settings, storage buckets) in a later milestone.
- **Hibernate `ddl-auto=update`.** Rejected: unreviewable, not repeatable.
- **jOOQ.** Not adopted now; `JdbcClient` covers the expected query load. Revisit if read
  models grow complex.
- **Supabase's `supabase/postgres` image in tests.** More faithful but heavy; the `postgis`
  image is enough for our own schema. Revisit if Supabase-specific extensions are adopted.

## Consequences

- An operator runbook is needed per environment for schema, roles and extension setup.
- Deployments have an explicit migrate step; the pipeline (Milestone for deployment) must
  enforce "migrate, then roll out".
- Flyway 12.4 is the Boot-managed version. Flyway's PostgreSQL page lists 9.2 and 18 as
  verified; our major version (U12) must be run in CI, which Testcontainers does.
