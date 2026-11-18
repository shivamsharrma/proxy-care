# Proxy Care backend

Spring Boot modular monolith serving the Proxy Care User and Caretaker apps
(`../proxy-care-client`). Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), database:
[docs/DATABASE.md](docs/DATABASE.md), testing: [docs/TESTING.md](docs/TESTING.md), and the
decision records in [docs/adr](docs/adr).

Status: Milestone 03 (persistence foundation). There are no business endpoints and no
authentication yet: every request except health, info, metrics and API docs is refused.

> **Upgrading a local database from before Milestone 03:** the database now uses dedicated roles
> (docs/DATABASE.md). Refresh `.env` from `.env.example`, then recreate the local database with
> `make db-reset db-up`. This deletes local data.

## Prerequisites

| Tool | Why |
|---|---|
| JDK 21 (Temurin) | Build toolchain. If it is missing, Gradle downloads one (foojay resolver). Gradle itself runs on Java 17+ |
| Docker | Tests start a PostGIS container (Testcontainers); local runs use `docker/compose.yaml` |
| `make` (optional) | Shortcuts below; every target is a single Gradle or Docker command |

## Quick start

```sh
./gradlew clean build      # compile, format check, all tests, coverage (needs Docker)

make env                   # create .env from .env.example, then edit if you like
make db-up                 # local PostGIS on 127.0.0.1:5432
make run                   # app on http://localhost:8080 with the local profile
```

Without `make` (for example on Windows):

```sh
cp .env.example .env
docker compose --env-file .env -f docker/compose.yaml up -d --wait
./gradlew bootRun          # gradlew.bat on Windows; profile defaults to local
```

Check it is up:

```sh
curl http://localhost:8080/actuator/health/readiness
open http://localhost:8080/swagger-ui.html
```

No vendor credentials are needed to start locally.

## Profiles

Exactly one profile must be active; start-up fails otherwise.

| Profile | Use | Database | Notes |
|---|---|---|---|
| `local` | Developer machine | `docker/compose.yaml`, credentials from `.env` | Readable logs, API docs on, Flyway runs at start-up |
| `test` | Automated tests | Testcontainers PostGIS | Quiet logs |
| `staging` | Shared test environment | Environment variables | JSON logs, actuator on port 8081, Flyway off (separate migrate step) |
| `prod` | Production | Environment variables | As staging, API docs off |

Staging and production refuse to start when the database settings are missing, point to a
local host, or do not use `sslmode=verify-full`, when Flyway is enabled at start-up, or when the
actuator shares the application port. Errors name the property, never its value. The rules are
in `DeploymentConfigurationValidator`.

Environment variables are listed in [.env.example](.env.example). No secret is stored in any
YAML file.

## Commands

| Task | Command |
|---|---|
| Full build | `./gradlew clean build` |
| Tests only | `./gradlew test` |
| Apply formatting | `./gradlew spotlessApply` |
| Check formatting | `./gradlew spotlessCheck` (part of `build`) |
| Tests + format + coverage gate | `./gradlew check` |
| Coverage report | `./gradlew jacocoTestReport` → `build/reports/jacoco/test/html/index.html` |
| Module diagrams | `build/spring-modulith-docs` (after `test`) |
| Update dependency locks | `./gradlew resolveAndLockAll --write-locks --no-configuration-cache` |

## Dependencies

- Versions: the Spring Boot and Spring Modulith BOMs, plus `gradle/libs.versions.toml` for
  everything else. Compatibility evidence: [ADR 0001](docs/adr/0001-framework-and-version.md).
- Every resolved version is recorded in `gradle.lockfile`. A dependency change without an
  updated lockfile fails the build.
- The Gradle wrapper is pinned by version and SHA-256 checksum.

## Layout

```
src/main/java/in/proxycare/
  ProxyCareApplication.java
  shared/        technical kernel (open module): api, error, security, logging, persistence,
                 money, time, idempotency, outbox, jobs, integration, i18n, config
  identity/      api, application, domain, infrastructure
  integrations/  vendor clients, one sub-package per vendor
  webhooks/      api, application, domain, infrastructure
  health/        readiness composition
src/main/resources/
  application.yml, application-{local,test,staging,prod}.yml
  db/migration/  Flyway migrations (from Milestone 03)
docker/compose.yaml   local database
docs/                 architecture and ADRs
```

Module boundaries are enforced by `ModularityTest` (Spring Modulith) and `ArchitectureTest`
(ArchUnit). Both run in every build.
