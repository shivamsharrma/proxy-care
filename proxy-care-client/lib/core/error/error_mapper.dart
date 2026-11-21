import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

import 'app_exception.dart';
import 'backend_error_code.dart';

/// Reads a [BackendError] from an error response body. The default is
/// [BackendError.parse]; an endpoint with a different error structure can
/// supply its own parser to [ErrorMapper] or [ErrorMapper.fromResponse].
typedef BackendErrorParser = BackendError Function(Object? body);

/// The parts of a backend error response the app relies on.
///
/// Every error is an RFC 9457 problem details body
/// (`application/problem+json`, ADR 0012):
///
/// ```json
/// {
///   "type": "urn:proxycare:problem:validation-error",
///   "title": "Validation failed",
///   "status": 422,
///   "detail": "The request contains invalid values.",
///   "instance": "/api/v1/patients",
///   "code": "VALIDATION_ERROR",
///   "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
///   "timestamp": "2026-11-18T09:30:00Z",
///   "errors": [
///     {"field": "age", "code": "Max", "message": "must be at most 120"}
///   ]
/// }
/// ```
///
/// Only `code`, `errors`, `traceId` and (for logs) `detail` / `title` are
/// read. The app branches on `code` only; `title`, `detail` and the field
/// messages are English developer text and are never shown as they are.
/// Independent of any feature DTO: it reads raw JSON.
final class BackendError {
  /// Creates a parsed backend error.
  const BackendError({
    this.code,
    this.message,
    this.fieldErrors = const {},
    this.traceId,
  });

  /// Parses a problem details object from [body]: a decoded JSON map or a
  /// JSON string, sent as `application/problem+json` or plain
  /// `application/json`. Anything else (an HTML error page, an empty body)
  /// yields an empty [BackendError], and the HTTP status alone classifies
  /// the error.
  factory BackendError.parse(Object? body) {
    final json = _asMap(body);
    if (json == null) return const BackendError();
    return BackendError(
      code: _string(json['code']),
      message: _string(json['detail']) ?? _string(json['title']),
      fieldErrors: _fieldErrors(json['errors']),
      traceId: _string(json['traceId']),
    );
  }

  /// `code`: stable machine-readable identifier.
  final String? code;

  /// `detail`, else `title`: technical English text, for logs only.
  final String? message;

  /// `errors`, as messages per field (`field` → `message`s, in order). An
  /// object-level error (empty or missing `field`) is under the empty
  /// string. An entry without a `message` contributes its constraint
  /// `code`, so the field is still marked.
  final Map<String, List<String>> fieldErrors;

  /// `traceId`: identifies the request in the backend's logs.
  final String? traceId;

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is Map<Object?, Object?>) return value.cast<String, Object?>();
    if (value is String && value.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<Object?, Object?>) {
          return decoded.cast<String, Object?>();
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static Map<String, List<String>> _fieldErrors(Object? value) {
    if (value is! List<Object?>) return const {};
    final errors = <String, List<String>>{};
    for (final entry in value) {
      if (entry is! Map<Object?, Object?>) continue;
      final field = entry['field'];
      final text = _string(entry['message']) ?? _string(entry['code']);
      if (text == null) continue;
      (errors[field is String ? field : ''] ??= []).add(text);
    }
    return errors;
  }
}

/// Parses a `Retry-After` header [value] given in seconds (the only form
/// the backend sends, ADR 0012). Null for a missing or negative value, or
/// one in the HTTP-date form.
Duration? parseRetryAfter(String? value) {
  final seconds = int.tryParse(value?.trim() ?? '');
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}

/// Translates any error raised by infrastructure into an [AppException].
///
/// The single place that knows about Dio's exceptions, HTTP status codes,
/// the backend's problem details and serialization errors. Data sources and
/// `guardResult` call it; nothing above the data layer sees a Dio type.
final class ErrorMapper {
  /// Creates the mapper. [parser] reads error bodies; the default reads
  /// problem details.
  const ErrorMapper({this.parser = BackendError.parse});

  /// Reads error response bodies.
  final BackendErrorParser parser;

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
  /// changes nothing. The backend code only refines what the status leaves
  /// open: a 400 / 422 is a [ValidationException] unless its code says it
  /// is a business-rule violation, and any 4xx that carries field errors is
  /// a [ValidationException], so backend validation errors always reach
  /// forms. A 429 or 503 keeps its `Retry-After` as
  /// [ServerException.retryAfter]. [parser] overrides the mapper's parser
  /// for one endpoint.
  AppException fromResponse(
    int? statusCode,
    Object? body, {
    Map<String, List<String>> headers = const {},
    Object? cause,
    BackendErrorParser? parser,
  }) {
    final backend = (parser ?? this.parser)(body);
    final message = backend.message;
    final code = backend.code;
    final traceId = backend.traceId;
    final isClientError =
        statusCode != null && statusCode >= 400 && statusCode < 500;
    final isBusinessRule =
        BackendErrorCode.fromWire(code) ==
        BackendErrorCode.businessRuleViolation;

    ValidationException validation() => ValidationException(
      message: message ?? 'The request was invalid.',
      fieldErrors: backend.fieldErrors,
      statusCode: statusCode,
      code: code,
      traceId: traceId,
      cause: cause,
    );

    ServerException server() => ServerException(
      message: message ?? 'The server failed to handle the request.',
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
      400 || 422 => isBusinessRule ? server() : validation(),
      401 => UnauthorizedException(
        message: message ?? 'Authentication is required.',
        code: code,
        traceId: traceId,
        cause: cause,
      ),
      403 => ForbiddenException(
        message: message ?? 'The action is not allowed.',
        code: code,
        traceId: traceId,
        cause: cause,
      ),
      404 || 410 => NotFoundException(
        message: message ?? 'The resource was not found.',
        statusCode: statusCode!,
        code: code,
        traceId: traceId,
        cause: cause,
      ),
      408 || 504 => TimeoutException(
        message: message ?? 'The request timed out.',
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
        if (inner != null && isSerializationError(inner)) {
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
