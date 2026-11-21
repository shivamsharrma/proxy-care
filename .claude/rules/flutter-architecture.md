---
paths:
  - "proxy-care-client/lib/**"
  - "proxy-care-client/test/**"
---
# Flutter architecture

Canonical source: `proxy-care-client/ARCHITECTURE.md` and
`docs/feature-guide.md`. This is the checklist.

## Layers
- `domain/`: entities (immutable, value equality), repository interfaces,
  use cases. Pure Dart. Returns `Result`/`AppFailure`, never throws infra
  exceptions.
- `data/`: DTOs (`*Dto`, json_serializable), mappers (`*Mapper`), data
  sources, `*RepositoryImpl`. Wrap calls with `guardResult`; map errors via
  `ErrorMapper`. DTOs stop at the mapper.
- `presentation/`: `*Controller` (`Notifier`/`AsyncNotifier`) + widgets.
  Talks to use cases / repository interfaces only.
- `<feature>_providers.dart`: the only feature file that names both an
  interface and its implementation.

## State and async
- Controllers expose `AsyncValue`; widgets render loading / data / error /
  empty explicitly — no silent spinners.
- After every `await` in a widget, check `context.mounted` (or `ref.mounted`
  in a notifier) before touching context/state.
- Never drop a Future in a callback (`onTap: () => vm.save()` where `save`
  returns Future): make the handler `async` and handle errors.

## UI
- Design-system widgets from `shared/widgets` and tokens from `core/theme`;
  no raw colors/sizes in feature code.
- Strings via `AppLocalizations` (ARB). Money via `core/formatting` rupee
  formatter, amounts as integer paise.
- Every tappable has semantics/label and ≥ 44 px target; layout adapts by
  constraints (`LayoutBuilder`), never by platform checks.
- Realtime (booking stage, payment status) arrives via a repository stream;
  widgets never open Supabase channels directly.

## Routing
- One `GoRouter` in `core/router`; features contribute a route module listed
  in `lib/app_routes.dart`. Guards use `AuthenticationState`.

## Adding a feature
Follow the `flutter-feature` skill. Add the feature's import rules to
`test/architecture/dependency_rules_test.dart` if it introduces a new folder kind.
