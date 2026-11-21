import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/error/error_reporter.dart';
import 'package:proxy_care_client/core/logging/app_logger.dart';

/// Mock of [ErrorReporter] for verifying what gets reported.
class MockErrorReporter extends Mock implements ErrorReporter {}

/// One entry written to a [RecordingLogger].
typedef LogEntry = ({
  LogLevel level,
  String message,
  Map<String, Object?> fields,
  Object? error,
  StackTrace? stackTrace,
});

/// An [AppLogger] that keeps every entry.
class RecordingLogger implements AppLogger {
  /// Entries in order.
  final entries = <LogEntry>[];

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => entries.add((
    level: level,
    message: message,
    fields: fields,
    error: error,
    stackTrace: stackTrace,
  ));
}
