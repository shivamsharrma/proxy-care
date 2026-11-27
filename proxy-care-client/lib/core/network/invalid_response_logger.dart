import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:retrofit/retrofit.dart';

import '../error/app_exception.dart';

/// Turns a response body that does not match its DTO into a
/// `ServerException.invalidResponse`.
///
/// Pass it as `errorLogger` when creating a Retrofit API class:
/// `PatientApi(dio, errorLogger: ref.watch(parseErrorLoggerProvider))`.
///
/// Retrofit's generated code calls [logError] only when decoding the body
/// failed, and then rethrows the error. Generated `fromJson` code reports a
/// wrong shape as a `TypeError` (for example `null` where a `String` was
/// expected, or an empty body where a DTO is expected), a `FormatException`
/// or, with `checked: true`, a `CheckedFromJsonException`. A `TypeError`
/// would otherwise reach the global error handlers as a programming error
/// (`guardResult` rethrows errors), so it is converted here, where it can
/// only come from decoding. Throwing from [logError] replaces the rethrown
/// error.
final class InvalidResponseLogger implements ParseErrorLogger {
  /// Creates the logger.
  const InvalidResponseLogger();

  @override
  void logError(
    Object error,
    StackTrace stackTrace,
    RequestOptions options, {
    Response<dynamic>? response,
  }) {
    if (error is TypeError ||
        error is FormatException ||
        error is CheckedFromJsonException) {
      throw ServerException.invalidResponse(
        statusCode: response?.statusCode,
        cause: error,
      );
    }
  }
}
