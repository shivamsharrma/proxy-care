/// Receives errors that no other code handled.
///
/// Pure Dart so any layer can depend on it. The default implementation logs
/// (see `LoggerErrorReporter`); a crash-reporting service can be plugged in
/// later by overriding `errorReporterProvider`.
abstract interface class ErrorReporter {
  /// Records [error] with its [stackTrace]. [context] says where the error was
  /// caught, for example `flutter` or `platform`.
  void report(Object error, StackTrace stackTrace, {String? context});
}
