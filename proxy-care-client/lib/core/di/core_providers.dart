import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../config/env.dart';
import '../error/crash_reporter.dart';
import '../error/error_mapper.dart';
import '../error/error_reporter.dart';
import '../error/logger_error_reporter.dart';
import '../formatting/app_formatters.dart';
import '../logging/app_logger.dart';
import '../logging/package_app_logger.dart';
import '../observability/analytics_service.dart';
import '../observability/performance_monitor.dart';

// Infrastructure providers shared by every feature.
//
// Conventions (see ARCHITECTURE.md, "Dependency injection"):
// * Providers are top-level `final` variables named `<thing>Provider`.
// * A provider's type is the abstraction callers need (for example
//   `ErrorReporter`), not the implementation class.
// * Resources that hold handles are closed with `ref.onDispose`.
// * Feature providers live in `features/<feature>/<feature>_providers.dart`.

/// The validated build configuration.
///
/// Has no default value: `createAppContainer` overrides it with the `Env`
/// read at start-up, and tests override it with a fixture. Reading it
/// without an override is a wiring bug.
final envProvider = Provider<Env>(
  (ref) => throw UnimplementedError(
    'envProvider has no default; override it (see createAppContainer).',
  ),
);

/// Application logger, at the level the environment allows
/// (`logLevelFor`); error text only in development. Sensitive data is
/// redacted before writing.
///
/// Lives for the whole app and is closed when the container is disposed.
final loggerProvider = Provider<AppLogger>((ref) {
  final env = ref.watch(envProvider);
  final logger = PackageAppLogger(
    minimumLevel: logLevelFor(env),
    includeErrorDetails: env.environment == AppEnvironment.development,
  );
  ref.onDispose(logger.close);
  return logger;
});

/// Destination for errors that nothing else handled.
///
/// Override it to send errors to a crash-reporting service.
final errorReporterProvider = Provider<ErrorReporter>(
  (ref) => LoggerErrorReporter(
    ref.watch(loggerProvider),
    crashReporter: ref.watch(crashReporterProvider),
  ),
);

/// Crash-reporting service. A no-op until Firebase Crashlytics is added
/// (backlog LL-05); override it then. Receives only privacy-safe
/// `CrashReport`s.
final crashReporterProvider = Provider<CrashReporter>(
  (ref) => const NoopCrashReporter(),
);

/// The analytics vendor adapter. A no-op until a vendor is chosen; override
/// it then. Features use [analyticsServiceProvider], never this.
final analyticsAdapterProvider = Provider<AnalyticsService>(
  (ref) => const NoopAnalyticsService(),
);

/// Product analytics for features: every event is filtered
/// ([FilteringAnalyticsService]) before reaching the adapter.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => FilteringAnalyticsService(ref.watch(analyticsAdapterProvider)),
);

/// Performance tracing. A no-op until a vendor is chosen; override it then.
final performanceMonitorProvider = Provider<PerformanceMonitor>(
  (ref) => const NoopPerformanceMonitor(),
);

/// Date, number and amount formatting (requires
/// `AppFormatters.initialize`, done in bootstrap).
final appFormattersProvider = Provider<AppFormatters>((ref) => AppFormatters());

/// Translates infrastructure errors (Dio, HTTP status, backend error bodies,
/// serialization) into `AppException`s. Data sources and repositories read
/// it; see `guardResult`.
final errorMapperProvider = Provider<ErrorMapper>((ref) => const ErrorMapper());
