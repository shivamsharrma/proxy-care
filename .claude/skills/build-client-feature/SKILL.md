---
name: build-client-feature
description: "Build or extend a Flutter feature module in proxy-care-client — domain, data, presentation, providers, routes, ARB strings and tests — with the Proxy Care specifics and gotchas on top of docs/feature-guide.md. Use when creating or changing screens, controllers, repositories or DTOs under lib/features."
---

# Build a client feature

The walkthrough and presentation rules are
`proxy-care-client/docs/feature-guide.md` (steps 1–12); the layer rules are
`proxy-care-client/ARCHITECTURE.md`; tests follow
`testing.md` and `proxy-care-client/TESTING.md`. This skill adds
only the Proxy Care specifics and gotchas.

## Proxy Care specifics
- Feature `README.md` lists the screen ids from the spec (e.g. P9a).
- Backend states (`REQUESTED`, `PAID`, `FAILED`, booking stages) are enums
  with an `unknown` fallback; DTO mappers map unrecognised values to it.
- Backend errors arrive as `ApiError.code`; map each code the endpoint can
  return (from the backend's contract handoff) in `ErrorMapper`.
- Strings in `lib/core/l10n/arb/*.arb` for every locale (English and Hindi).
- Routes guarded by role (user app vs caretaker app) via `core/router`.
- Fake repository in `test/features/<feature>/fakes.dart`.
- Finish with the client full gate (`testing.md` → Commands).

## Gotchas
- Spec texts like "Payment request sent to {User}" use the first name —
  check the spec's examples, and build them with ARB placeholders.
- Buttons whose enabled state depends on server state (Continue enabled
  only when PAID) read it from the controller, never from a local flag set
  on tap.
- Give tappables a stable `Semantics(identifier:)`/`Key` so Maestro can
  select them by `id:`.
