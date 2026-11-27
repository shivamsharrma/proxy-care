import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

import 'app_exception.dart';
import 'backend_error_parser.dart';

/// Reads a [BackendError] from an error response body. The default is
/// [BackendErrorParser.parse]; an endpoint with a different error structure
/// can supply its own to [ErrorMapper] or [ErrorMapper.fromResponse].
typedef ErrorBodyParser = BackendError Function(Object? body);

/// Parses a `Retry-After` header in seconds. The backend sends none today.
/// Null for a missing or negative [value], or one in the HTTP-date form.
Duration? parseRetryAfter(String? value) {
  final seconds = int.tryParse(value?.trim() ?? '');
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}

/// Translates any error raised by infrastructure into an [AppException].
///
/// The single place that knows about Dio's exceptions, HTTP status codes,
/// the backend's `ApiError` body and serialization errors. Data sources and
/// `guardResult` call it; nothing above the data layer sees a Dio type.
final class ErrorMapper {
  /// Creates the mapper. [parser] reads error bodies; the default reads
  /// the backend's `ApiError`.
  const ErrorMapper({this.parser = BackendErrorParser.parse});

  /// Reads error response bodies.
  final ErrorBodyParser parser;

  /// Maps [error] to an [AppException]. Existing [AppException]s are
  /// returned unchanged; unclassifiable errors become [UnknownException].
  AppException map(Object error) {
    return switch (error) {
      AppException() => error,
      DioException() => _fromDio(error),
      _ when isSerializationError(error) => ServerException.invalidResponse(
        cause: error,
      ),
      _ => UnknownException(cause: error),
    };
  }

  /// Maps an HTTP error response by its [statusCode], [body] and
  /// [headers].
  ///
  /// The status decides the exception type; a missing or unknown `code`
  /// changes nothing. A 400 is a [ValidationException]; a 422 (the
  /// backend's business-rule status) is a [ServerException] whatever its
  /// code; any 4xx that carries field errors is a [ValidationException], so
  /// backend validation errors always reach forms. The exception's message
  /// is the type's fixed default: the server's `message` is never copied
  /// onto it. A 429 or 503 keeps its `Retry-After` as
  /// [ServerException.retryAfter]. [parser] overrides the mapper's parser
  /// for one endpoint.
  AppException fromResponse(
    int? statusCode,
    Object? body, {
    Map<String, List<String>> headers = const {},
    Object? cause,
    ErrorBodyParser? parser,
  }) {
    final backend = (parser ?? this.parser)(body);
    final code = backend.code;
    final traceId = backend.traceId;
    final isClientError =
        statusCode != null && statusCode >= 400 && statusCode < 500;

    ValidationException validation() => ValidationException(
      fieldErrors: backend.fieldErrors,
      statusCode: statusCode,
      code: code,
      traceId: traceId,
      cause: cause,
    );

    ServerException server() => ServerException(
      statusCode: statusCode,
      code: code,
      traceId: traceId,
      retryAfter: statusCode == 429 || statusCode == 503
          ? parseRetryAfter(_header(headers, 'retry-after'))
          : null,
      cause: cause,
    );

    if (isClientError && backend.fieldErrors.isNotEmpty) return validation();

    return switch (statusCode) {
      400 => validation(),
      401 => UnauthorizedException(
        code: code,
        traceId: traceId,
        cause: cause,
      ),
      403 => ForbiddenException(
        code: code,
        traceId: traceId,
        cause: cause,
      ),
      404 || 410 => NotFoundException(
        statusCode: statusCode!,
        code: code,
        traceId: traceId,
        cause: cause,
      ),
      408 || 504 => TimeoutException(
        statusCode: statusCode,
        code: code,
        traceId: traceId,
        cause: cause,
      ),
      _ => server(),
    };
  }

  /// The first value of header [name] (lower case) in [headers], matched
  /// case-insensitively.
  static String? _header(Map<String, List<String>> headers, String name) {
    for (final MapEntry(:key, :value) in headers.entries) {
      if (key.toLowerCase() == name && value.isNotEmpty) return value.first;
    }
    return null;
  }

  AppException _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutException(cause: error);
      case DioExceptionType.cancel:
        return CancelledException(cause: error);
      case DioExceptionType.connectionError:
        return NetworkException(cause: error);
      case DioExceptionType.badCertificate:
        return NetworkException(
          message: 'The server certificate was rejected.',
          cause: error,
        );
      case DioExceptionType.badResponse:
        final response = error.response;
        return fromResponse(
          response?.statusCode,
          response?.data,
          headers: response?.headers.map ?? const {},
          cause: error,
        );
      case DioExceptionType.unknown:
        final inner = error.error;
        if (inner is AppException) return inner;
        // A TypeError carried by Dio is its own cast of the response body
        // (an object where a list is expected, text where an object is).
        if (inner != null &&
            (isSerializationError(inner) || inner is TypeError)) {
          return ServerException.invalidResponse(
            statusCode: error.response?.statusCode,
            cause: error,
          );
        }
        return UnknownException(cause: error);
    }
  }

  /// Whether [error] means a payload could not be decoded or did not match
  /// the expected shape: invalid JSON, or a `json_serializable` check
  /// failure.
  static bool isSerializationError(Object error) =>
      error is FormatException || error is CheckedFromJsonException;
}
