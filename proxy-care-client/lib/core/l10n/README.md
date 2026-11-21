# core/l10n

Localization with Flutter's ARB tooling (`flutter gen-l10n`, configured in
`l10n.yaml`).

- `arb/app_en.arb`: every user-facing string. English only for now; add
  `app_<locale>.arb` to add a language.
- `generated/`: output of `flutter gen-l10n` (`make gen`). Committed and
  checked by CI; never edit by hand.
- `error_messages.dart`: the central failure → message mapping
  (`failureMessage`, `fieldErrorMessage`). Screens never show backend
  messages, exception text or stack traces.

## Locales

English (`en`) is the only and initial locale. `MaterialApp` uses
`AppLocalizations.supportedLocales`, so a device in any other language
falls back to English. Dates and numbers are formatted for India by
`AppFormatters` (`core/formatting`), not by the ARB files.

To add a language: add `arb/app_<code>.arb` with every key of
`app_en.arb`, run `make gen`, and commit the generated files.

## Conventions

- **No user-facing literal strings** in widgets, controllers or failure
  mappings: every string is an ARB message read with
  `AppLocalizations.of(context).<key>`.
- **Keys** are lowerCamelCase and start with their area: `error…` for
  failure messages, `a11y…` for screen-reader labels, then the feature
  name (`bookingConfirmTitle`, `visitsEmptyMessage`). One key per use;
  don't reuse a key because the English happens to match.
- **Every message has a `description`** saying where it appears (a test
  enforces this).
- **Interpolation:** typed placeholders (`{position}` with
  `"type": "int"`), never string concatenation. Pass dates, times and
  amounts already formatted by `AppFormatters` as `String` placeholders.
- **Plurals:** ICU plural syntax, e.g.
  `"durationHours": "{count, plural, =1{1 hour} other{{count} hours}}"`.
  Use `select` for variants by a value (`{sex, select, …}`).
- Never show backend messages or exception text; map failures with
  `failureMessage`.
