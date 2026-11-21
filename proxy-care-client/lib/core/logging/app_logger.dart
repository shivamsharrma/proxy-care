import '../config/app_environment.dart';
import '../config/env.dart';

/// Severity of a log entry, lowest first. [off] disables logging.
enum LogLevel { debug, info, warning, error, off }

/// The app's logger. Pure Dart; every layer may depend on it.
///
/// Conventions:
/// - [message] is a constant description of what happened
///   (`'Booking created'`), never built from user data.
/// - Variable data goes in [fields] (`{'bookingId': id}`); the
///   implementation masks sensitive keys and values before writing.
/// - Pass errors as [error]; whether their text is written depends on the
///   environment (see [PackageAppLogger]).
/// - Never call `print`: the analyzer rejects it.
abstract interface class AppLogger {
  /// Writes one entry at [level].
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  });
}

/// Shorthands for [AppLogger.log].
extension AppLoggerLevels on AppLogger {
  /// Writes a debug entry: detail useful only while developing.
  void debug(String message, {Map<String, Object?> fields = const {}}) =>
      log(LogLevel.debug, message, fields: fields);

  /// Writes an info entry: a normal, noteworthy event.
  void info(String message, {Map<String, Object?> fields = const {}}) =>
      log(LogLevel.info, message, fields: fields);

  /// Writes a warning: something unexpected that the app recovered from.
  void warning(
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.warning,
    message,
    fields: fields,
    error: error,
    stackTrace: stackTrace,
  );

  /// Writes an error: a failure that needs attention.
  void error(
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.error,
    message,
    fields: fields,
    error: error,
    stackTrace: stackTrace,
  );
}

/// The minimum level written for [env]: everything in development, info
/// and above in staging, warnings and errors in production, nothing when
/// `ENABLE_LOGGING` is false.
LogLevel logLevelFor(Env env) {
  if (!env.enableLogging) return LogLevel.off;
  return switch (env.environment) {
    AppEnvironment.development => LogLevel.debug,
    AppEnvironment.staging => LogLevel.info,
    AppEnvironment.production => LogLevel.warning,
  };
}
