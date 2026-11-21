---
name: flutter-feature
description: Checklist for adding or extending a Flutter feature module in proxy-care-client (domain/data/presentation, providers, routes, ARB strings, tests). Use when creating screens, controllers, repositories or DTOs in lib/features.
---

# Flutter feature

The full walkthrough is `proxy-care-client/docs/feature-guide.md` (steps
1–12). Read it; this skill is the checklist and the gotchas.

## Checklist
- [ ] `lib/features/<feature>/` with `domain/`, `data/`, `presentation/`,
      `<feature>_providers.dart`, `README.md` (screen ids from the spec, e.g. P9a).
- [ ] Domain entities immutable with value equality; enums for backend states
      (`REQUESTED`, `PAID`, `FAILED`, booking stages) with an `unknown` fallback.
- [ ] Repository interface returns `Result<T>`; streams for realtime state.
- [ ] DTOs (`json_serializable`) + mapper; unknown enum values map to `unknown`.
- [ ] Data source on the shared Dio client (`core/network`) / Supabase
      adapter; wrap in `guardResult`.
- [ ] Controller (`AsyncNotifier`) per screen; exposes UI state, takes
      intents as methods; no BuildContext.
- [ ] Screen widget renders loading / data / error / empty from `AsyncValue`;
      uses `shared/widgets` + `core/theme` tokens.
- [ ] Strings in `lib/core/l10n/arb/*.arb` (all locales), then `make gen`.
- [ ] Route module added to `lib/app_routes.dart`, guarded by role
      (user app vs caretaker app) via `core/router` route access.
- [ ] Tests: fake repo in `test/features/<feature>/fakes.dart`; controller
      unit tests; widget tests per screen state; Maestro flows per scenario.
- [ ] `make gen && make format && make analyze && make test`.

## Gotchas
- Spec texts like "Payment request sent to {User}" use the first name —
  check the spec's examples, and build them with ARB placeholders.
- Buttons whose enabled state depends on server state (Continue enabled
  only when PAID) read it from the controller, never from a local flag set
  on tap.
- Money displayed via the rupee formatter from integer paise.
- Give tappables a stable `Semantics(identifier:)`/`Key` so Maestro can
  select them by `id:`.
