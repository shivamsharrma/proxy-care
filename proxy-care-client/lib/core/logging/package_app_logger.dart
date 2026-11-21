import 'dart:convert';

import 'package:logger/logger.dart';

import '../security/redactor.dart';
import 'app_logger.dart';

/// [AppLogger] over the `logger` package, writing one line per entry:
/// `[I]  Booking created {"bookingId":"b-1","phone":"***"}`.
///
/// Before writing, the message and field values pass through [redactor]
/// (sensitive keys masked, tokens, emails and long numbers masked in text).
/// An error is written as its type only, unless [includeErrorDetails] is
/// set (development builds), because error messages can carry tokens or
/// health information; even then its text is redacted.
final class PackageAppLogger implements AppLogger {
  /// Creates a logger writing entries at [minimumLevel] and above.
  PackageAppLogger({
    required this.minimumLevel,
    this.includeErrorDetails = false,
    this.redactor = const Redactor(),
    LogOutput? output,
  }) : _logger = Logger(
         filter: ProductionFilter(),
         level: Level.trace,
         printer: SimplePrinter(colors: false),
         output: output,
       );

  final Logger _logger;

  /// The lowest level written.
  final LogLevel minimumLevel;

  /// Whether error text (redacted) is written, not only the error type.
  final bool includeErrorDetails;

  /// What masks sensitive data.
  final Redactor redactor;

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level == LogLevel.off ||
        minimumLevel == LogLevel.off ||
        level.index < minimumLevel.index) {
      return;
    }
    final line = StringBuffer(redactor.text(message));
    if (fields.isNotEmpty) {
      final safe = redactor.json(fields);
      line.write(' ${redactor.text(jsonEncode(safe, toEncodable: _string))}');
    }
    if (error != null) {
      line.write(' error=${error.runtimeType}');
      if (includeErrorDetails) line.write(': ${redactor.text('$error')}');
    }
    _logger.log(_levels[level]!, line.toString(), stackTrace: stackTrace);
  }

  /// Closes the underlying output.
  Future<void> close() => _logger.close();

  static Object? _string(Object? value) => '$value';

  static const _levels = {
    LogLevel.debug: Level.debug,
    LogLevel.info: Level.info,
    LogLevel.warning: Level.warning,
    LogLevel.error: Level.error,
  };
}
