---
name: build-backend-feature
description: "Build or modify backend features and vendor integrations in proxy-care-backend using Spring Boot best practices. Covers tests, Flyway migrations, entities, repositories, ErrorCodes, services, controllers, security, vendor integrations, and API contract handoff."
---

# Build Backend Feature

Build clean, secure, maintainable backend features in `proxy-care-backend` using Java 21+ and Spring Boot 3.x.

Follow existing project conventions. Prefer simple, working solutions over unnecessary abstractions or overengineering.

## 1. Read Project Conventions

Before implementation, inspect:

- `.claude/rules/backend-code.md` — architecture, entities, identity, errors, vendors, configuration.
- `.claude/rules/testing.md` — test setup, server, and commands.
- `.claude/rules/backend-events.md` — inter-feature events, when applicable.
- `proxy-care-backend/ARCHITECTURE.md` — architectural boundaries.

Use `com.proxycare.features.profile` as the reference feature.

Project-specific conventions always take precedence over generic best practices.

## 2. Feature Development Workflow

Complete each step before moving to the next.

1. **Understand:** Inspect related code, identify requirements, affected components, ownership/security rules, database changes, and API contracts.

2. **Tests first:** Write tests for happy path, validation failures, unauthenticated requests (401), unauthorized resource access (404), missing resources, illegal business states, and relevant edge cases. Run them and verify expected failures. Skip only when adequate tests already exist.

3. **Migration:** If the schema changes, use the `write-db-migration` skill and Flyway. Follow existing naming and database conventions.

4. **Entity & Repository:** Follow `backend-code.md`. Use Spring Data JPA, appropriate mappings, and owner/tenant-scoped queries. Never trust frontend-supplied identity for authorization.

5. **Errors:** Add required `ErrorCode` constants and reuse existing exception-handling mechanisms. Introduce feature-specific exceptions only when necessary.

6. **Service:** Implement `I<Feature>Service` and `<Feature>Service` following existing conventions. Handle business logic, transactions, mapping, ownership checks, and events where required.

7. **Controller:** Implement REST endpoints under `/api/v1/<kebab-case-path>`. Use validated request DTOs, appropriate HTTP methods/status codes, and keep controllers thin.

8. **Vendor/Public APIs:** Follow `backend-code.md` → Vendors for public endpoints and the vendor workflow below for external integrations.

9. **Verification:** Run feature tests, followed by the complete server validation gate from `testing.md`. Fix failures until green. Never claim tests passed without executing them.

## 3. Spring Boot Best Practices

- Use Java 21+, Spring Boot 3.x, and `jakarta.*`.
- Organize packages by feature/domain.
- Use constructor injection with `private final` dependencies; avoid field injection.
- Prefer records for request/response DTOs and immutable models.
- Use `@RestController`, `@Service`, and `@Repository` appropriately.
- Keep business logic in services, not controllers.
- Use `@Transactional` at the service layer for database modifications.
- Use Jakarta Bean Validation (`@Valid`, `@NotNull`, `@NotBlank`, `@Size`, etc.).
- Never expose JPA entities directly through APIs.
- Externalize configuration and secrets. Prefer `@ConfigurationProperties` for grouped configuration.
- Use parameterized SLF4J logging. Never log credentials, tokens, or sensitive data.
- Prevent N+1 queries, use pagination where appropriate, and use parameterized database queries.

## 4. Vendor Integration

Follow `proxy-care-backend/ARCHITECTURE.md` → Layers and use `infrastructure/payment` as the template.

Structure:

`com.proxycare.infrastructure.<capability>/`
- Interface
- `model/`
- `exception/`

`com.proxycare.infrastructure.<capability>.<vendor>/`
- Configuration and properties
- Gateway/client
- Mapper
- Vendor-specific DTOs

Keep vendor-specific details inside infrastructure. Expose the capability interface to application/business layers.

Use validated `@ConfigurationProperties`, environment variables for secrets, and WireMock integration tests based on vendor sandbox documentation. Never use live credentials in tests.

## 5. MVP and Complexity Rules

- Implement only what the requirement needs.
- Reuse existing code and project patterns.
- Avoid unnecessary interfaces, factories, builders, wrappers, and exception classes.
- Do not introduce dependencies without justification.
- Avoid speculative features, premature optimization, and unrelated refactoring.
- Prefer generic exceptions where appropriate.
- Do not duplicate existing validation or utilities.

Choose the simplest solution that maintains correctness, security, and maintainability.

## 6. Client Contract Handoff

After successful implementation, provide:

- Endpoint and HTTP method.
- Authentication requirements and headers.
- Complete request JSON.
- Complete successful response JSON.
- Every possible `ErrorCode` with its HTTP status and response structure.

Use camelCase consistently so Flutter DTOs and `ErrorMapper` match the backend.

Local OpenAPI specification: `/v3/api-docs`.

## 7. Final Report

Summarize:

1. Implementation and modified components.
2. Database migrations, if any.
3. API contract.
4. Security and ownership behavior.
5. ErrorCodes and HTTP statuses.
6. Tests executed and actual results.

Never report unverified implementation or test results.