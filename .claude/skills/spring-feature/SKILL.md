---
name: spring-feature
description: Checklist for adding a Spring Boot use case/endpoint in proxy-care-server (hexagonal context, REST controller, persistence, authZ, tests). Use for any new or changed server API.
---

# Spring feature

Rules: `.claude/rules/spring-backend.md`, `security.md`.

## Checklist
- [ ] Context package `com.proxycare.<context>` exists (booking, caretaker,
      ride, payment, hospital, identity); else add it with an ArchUnit rule.
- [ ] Domain: aggregate method enforcing the transition + domain event;
      unit tests with no Spring context.
- [ ] Application: use-case service, `@Transactional`, ownership check
      (sponsor or assigned caretaker) → `AccessDeniedException` → 403.
- [ ] Ports for anything external; adapters implement them.
- [ ] Web: `/api/v1/...` controller, request/response records with Bean
      Validation, `Idempotency-Key` for POST/PUT, errors as `ProblemDetail`
      with a stable `type` (`https://api.proxycare.in/problems/<code>`).
- [ ] Persistence: JPA entity in adapter, `@Version`, migration under
      `supabase/migrations` (with RLS — see `supabase-migration-and-rls`).
- [ ] Events via outbox (`kafka-event` skill) if other contexts react.
- [ ] Tests: `@WebMvcTest` (validation, 401/403/409), Testcontainers
      integration for the use case, access-control scenarios from the spec.
- [ ] OpenAPI annotations so the client contract is generated, not guessed.
- [ ] `./gradlew spotlessApply build`.

## Contract handoff
Report the endpoint, request/response JSON and error `type`s so the
Flutter DTOs and `ErrorMapper` entries match exactly.
