/// Vendor-independent crash reporting. The MVP uses [NoopCrashReporter];
/// Firebase Crashlytics (backlog LL-05) will implement [CrashReporter]
/// without changes elsewhere.
///
/// Privacy: a [CrashReport] carries only the error's type, the stack trace
/// and where it was caught. The error object and its message are not part
/// of it, because messages can contain healthcare information, patient
/// data or tokens that must never reach a crash-reporting service.
///
/// Pure Dart.
library;

/// What is sent to a crash-reporting service.
final class CrashReport {
  /// Creates a report.
  const CrashReport({
    required this.errorType,
    required this.stackTrace,
    this.context,
    this.fatal = false,
  });

  /// Builds a report from an [error] without keeping the error itself.
  factory CrashReport.from(
    Object error,
    StackTrace stackTrace, {
    String? context,
    bool fatal = false,
  }) => CrashReport(
    errorType: error.runtimeType.toString(),
    stackTrace: stackTrace,
    context: context,
    fatal: fatal,
  );

  /// The error's runtime type, e.g. `StateError`.
  final String errorType;

  /// Where the error was thrown.
  final StackTrace stackTrace;

  /// Where it was caught (`flutter`, `platform`, `zone`, `repository`).
  final String? context;

  /// Whether nothing handled the error.
  final bool fatal;
}

/// Sends [CrashReport]s to a crash-reporting service.
abstract interface class CrashReporter {
  /// Records [report]. Must not throw.
  void record(CrashReport report);
}

/// Discards every report (crash reporting is not set up in the MVP).
final class NoopCrashReporter implements CrashReporter {
  /// Creates a no-op reporter.
  const NoopCrashReporter();

  @override
  void record(CrashReport report) {}
}
