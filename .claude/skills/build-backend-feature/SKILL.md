---
name: build-backend-feature
description: "Build or change a backend feature in proxy-care-backend — tests, Flyway migration, entity, repository, ErrorCodes, service, controller — or add a vendor behind an infrastructure interface, ending with a contract handoff for the client. Use for any new or changed backend endpoint or vendor integration."
---

# Build a backend feature

The conventions live in `.claude/rules/backend-code.md` (layout, errors,
identity, vendors) and `testing.md` (Server, Commands); this skill
is only the order of work. Copy the `profile` feature
(`com.proxycare.features.profile`) when in doubt.

## Feature
1. **Tests first** (`testing.md` → Server) — skip if the slice's tests
   already exist (pipeline): happy path, `VALIDATION_FAILED`, 401 without a
   token, someone else's resource → 404, each illegal state → its
   `ErrorCode`. Run them and see them fail.
2. **Migration** for new tables/columns: `write-db-migration` skill.
3. **Entity + repository** (`backend-code.md` → Entities, Identity):
   repository lookups scoped by the owner.
4. **Errors:** new `ErrorCode` constant(s) + feature exception
   (`backend-code.md` → Errors).
5. **Service:** `I<Feature>Service` + `<Feature>Service`, mapper to response
   DTOs, events for other features (`backend-events.md`).
6. **Controller** under `/api/v1/<kebab-path>` with `@Valid` request records.
7. Public path (e.g. a webhook)? `backend-code.md` → Vendors.
8. Run the specific tests, then the server full gate
   (`testing.md` → Commands) until green.

## Vendor (infrastructure capability)
1. Interface + `model/` + `exception/` in
   `com.proxycare.infrastructure.<capability>/`, then the
   `<capability>/<vendor>/` sub-package (config, properties, gateway, mapper,
   vendor DTOs) — the `infrastructure/payment` example in
   `proxy-care-backend/ARCHITECTURE.md` → Layers is the template.
2. Properties and env vars per `backend-code.md` → Vendors and config.
3. Tests against WireMock stubs built from the vendor's sandbox docs; never
   live keys.

## Contract handoff
Report for the client: endpoint + method, request/response JSON (camelCase),
and every `ErrorCode` it can return with its status, so the Flutter DTOs and
`ErrorMapper` match exactly. Locally the OpenAPI spec is at `/v3/api-docs`.
