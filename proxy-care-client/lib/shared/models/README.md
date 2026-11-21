# shared/models

Small value types used across features and layers, such as `Result`.

- Pure Dart: no Flutter, Dio or Riverpod imports. The domain layer depends
  on these types, and the architecture test enforces it.
- Immutable, with value equality (hand-written or Freezed).
- No API (DTO) shapes: those belong to a feature's `data/dto`.
