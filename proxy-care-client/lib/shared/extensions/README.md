# shared/extensions

Extension methods on Dart and Flutter types used by more than one feature
(for example `BuildContext` shortcuts or `DateTime` formatting).

- One file per extended type: `build_context_x.dart`, `date_time_x.dart`.
- Name extensions `<Type>X`.
- Keep pure-Dart extensions separate from Flutter ones so domain code can
  use the pure ones.
