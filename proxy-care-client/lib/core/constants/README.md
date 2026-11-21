# core/constants

App-wide, feature-agnostic constants: timeouts, storage key names, header
names, layout breakpoints.

- One file per topic (`network_constants.dart`, `storage_keys.dart`), not one
  big `constants.dart`.
- Use `static const` members on an `abstract final class` so values are
  namespaced: `StorageKeys.accessToken`.
- No environment-specific values: those belong in `core/config` (`Env`).
- Feature-specific constants stay inside the feature.
