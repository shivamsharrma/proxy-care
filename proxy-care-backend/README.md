# Proxy Care backend

Spring Boot 4.1 (Java 21) API shared by the Proxy Care User and Caretaker apps.
Supabase provides Postgres, phone-OTP auth and storage; this service is the only writer of business data.

## Build and test

Prerequisites: Java 21 and Docker (tests start a PostGIS container with Testcontainers).

```sh
./gradlew clean build
```

Configuration is read from environment variables; see `.env.example`.

Milestone progress: `docs/MILESTONES.md`. Deferred decisions: `docs/LATER.md`.
