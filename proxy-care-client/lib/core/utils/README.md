# core/utils

Small, pure, stateless helpers that are not tied to a feature or a widget:
formatting, parsing, validation helpers.

- Prefer top-level functions or `abstract final class` namespaces.
- Must be pure Dart unless the helper is inherently about Flutter.
- If a helper is only used by one feature, keep it in that feature.
- Each helper has unit tests in `test/core/utils/`.
