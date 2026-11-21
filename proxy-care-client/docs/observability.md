# Logging and observability

Every service here is an interface with a no-op (or local) default, so no
vendor SDK is part of the app. A vendor is added later as one adapter
class and one provider override.

| Concern | Interface | Default | Provider |
| --- | --- | --- | --- |
| Logging | `AppLogger` (`core/logging`) | `PackageAppLogger` (console, redacted) | `loggerProvider` |
| Unhandled errors | `ErrorReporter` (`core/error`) | logs + forwards to the crash reporter | `errorReporterProvider` |
| Crash reporting | `CrashReporter` (`core/error`) | `NoopCrashReporter` | `crashReporterProvider` |
| Analytics | `AnalyticsService` (`core/observability`) | `NoopAnalyticsService` behind `FilteringAnalyticsService` | adapter: `analyticsAdapterProvider`; features use `analyticsServiceProvider` |
| Performance | `PerformanceMonitor` (`core/observability`) | `NoopPerformanceMonitor` | `performanceMonitorProvider` |

## Logging

```dart
final log = ref.read(loggerProvider);
log.info('Booking created', fields: {'bookingId': booking.id});
log.warning('Retrying upload', fields: {'attempt': 2}, error: error);
```

- Levels: debug, info, warning, error. The minimum level follows the
  environment (`logLevelFor`): development `debug`, staging `info`,
  production `warning`, and nothing when `ENABLE_LOGGING=false` (the
  production default). Override `loggerProvider` to change it.
- Messages are constant text; data goes in `fields`. Field values with a
  sensitive key are masked, and every written line is scanned for tokens,
  email addresses and long numbers (`Redactor`).
- Errors are written as their type only, except in development builds,
  where their (redacted) text is added.
- `print` is rejected by the analyzer (`avoid_print`); the `logger`
  package is used only inside `core/logging` (architecture test).

## Adding a vendor adapter

1. Add the vendor package and implement the interface in one file, for
   example `core/observability/firebase_analytics_service.dart`
   implementing `AnalyticsService`. Keep the vendor import in that file.
2. Override the provider at start-up (in `main.dart`'s `bootstrap`
   overrides), for example
   `analyticsAdapterProvider.overrideWithValue(FirebaseAnalyticsService())`.
   Initialize the SDK in bootstrap if it needs it.
3. Add an architecture rule so only that folder imports the vendor.
4. Check what the vendor collects by default (device identifiers,
   advertising ID, automatic screen events) and turn off what the privacy
   rules in SECURITY.md do not allow.

Rules for adapters:

- **Crash reporting** receives `CrashReport`s: error type, stack trace and
  context only, never the error message (`CrashReport.from`). Planned:
  Firebase Crashlytics (backlog LL-05).
- **Analytics** adapters only ever see events that passed
  `FilteringAnalyticsService`: snake_case names, no sensitive keys,
  `num`/`bool`/short `String` values without personal data. Do not set a
  user identifier at the vendor without a privacy review; if one is set,
  clear it in a `SessionCleanup` task.
- **Performance** trace names follow the analytics naming rules.
- An adapter must never throw into app code: catch and drop.
