import '../logging/app_logger.dart';
import 'crash_reporter.dart';
import 'error_reporter.dart';

/// [ErrorReporter] that writes errors to the application [AppLogger] and
/// forwards a privacy-safe [CrashReport] to the [CrashReporter].
///
/// The logger stays the primary sink: crash reporting is added next to it,
/// never instead of it.
final class LoggerErrorReporter implements ErrorReporter {
  /// Creates a reporter that writes to [logger] and [crashReporter].
  const LoggerErrorReporter(
    this._logger, {
    this.crashReporter = const NoopCrashReporter(),
  });

  final AppLogger _logger;

  /// Where privacy-safe crash reports go.
  final CrashReporter crashReporter;

  /// Contexts of errors that nothing handled.
  static const Set<String> _uncaughtContexts = {'flutter', 'platform', 'zone'};

  @override
  void report(Object error, StackTrace stackTrace, {String? context}) {
    _logger.error(
      'Unhandled error',
      fields: {'context': ?context},
      error: error,
      stackTrace: stackTrace,
    );
    crashReporter.record(
      CrashReport.from(
        error,
        stackTrace,
        context: context,
        fatal: _uncaughtContexts.contains(context),
      ),
    );
  }
}
