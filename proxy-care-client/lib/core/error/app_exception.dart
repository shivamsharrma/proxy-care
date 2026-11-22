/// Infrastructure exceptions: what went wrong talking to the outside world
/// (network, backend, storage), independent of the HTTP client.
///
/// Data sources throw these, usually after `ErrorMapper` has translated a
/// client exception. They never cross a repository: repositories convert
/// them into `AppFailure`s (see `guardResult`). The domain layer must not
/// import this file (enforced by the architecture test).
///
/// [message] is a fixed developer default for the type: never the server's
/// `message` (which can echo personal data), never shown to users.
///
/// Note: [TimeoutException] has the same name as `dart:async`'s; a file that
/// needs both imports `dart:async` with `hide TimeoutException`.
library;

import 'backend_error_code.dart';

/// Base of the infrastructure exception hierarchy.
sealed class AppException implements Exception {
  const AppException(
    this.message, {
    this.statusCode,
    this.code,
    this.traceId,
    this.cause,
  });

  /// Developer-facing description.
  final String message;

  /// HTTP status, when the error came from a response.
  final int? statusCode;

  /// Machine-readable error code sent by the backend (the `ApiError`
  /// `code`), as sent. See [errorCode] for the standard codes.
  final String? code;

  /// The `ApiError`'s `meta.traceId`: identifies the request in the backend's logs
  /// and traces. Log it and quote it to support; never show it as an
  /// error message.
  final String? traceId;

  /// [code] as a standard [BackendErrorCode], or null if it is not one.
  BackendErrorCode? get errorCode => BackendErrorCode.fromWire(code);

  /// The original error (for example the `DioException`), for logs.
  final Object? cause;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' $statusCode';
    final backendCode = code == null ? '' : ' [$code]';
    return '$runtimeType$status$backendCode: $message';
  }
}

/// The server could not be reached (no connection, DNS, refused, TLS).
final class NetworkException extends AppException {
  /// Creates a network exception.
  const NetworkException({
    String message = 'The server could not be reached.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// The request had no valid credentials (HTTP 401).
final class UnauthorizedException extends AppException {
  /// Creates an unauthorized exception.
  const UnauthorizedException({
    String message = 'Authentication is required.',
    String? code,
    String? traceId,
    Object? cause,
  }) : super(
         message,
         statusCode: 401,
         code: code,
         traceId: traceId,
         cause: cause,
       );
}

/// The credentials are valid but not allowed to do this (HTTP 403).
final class ForbiddenException extends AppException {
  /// Creates a forbidden exception.
  const ForbiddenException({
    String message = 'The action is not allowed.',
    String? code,
    String? traceId,
    Object? cause,
  }) : super(
         message,
         statusCode: 403,
         code: code,
         traceId: traceId,
         cause: cause,
       );
}

/// The resource does not exist or no longer exists (HTTP 404 / 410).
final class NotFoundException extends AppException {
  /// Creates a not-found exception.
  const NotFoundException({
    String message = 'The resource was not found.',
    int statusCode = 404,
    String? code,
    String? traceId,
    Object? cause,
  }) : super(
         message,
         statusCode: statusCode,
         code: code,
         traceId: traceId,
         cause: cause,
       );
}

/// The backend rejected the input (HTTP 400, or any 4xx that carries field
/// errors).
///
/// [fieldErrors] maps a field name (a property path such as `patient.age`
/// or `purposes[0]`) to its single message, from the backend's
/// `fieldErrors`. It is unmodifiable.
final class ValidationException extends AppException {
  /// Creates a validation exception. [fieldErrors] is copied.
  ValidationException({
    String message = 'The request was invalid.',
    Map<String, String> fieldErrors = const {},
    int? statusCode = 400,
    String? code,
    String? traceId,
    Object? cause,
  }) : fieldErrors = Map.unmodifiable(fieldErrors),
       super(
         message,
         statusCode: statusCode,
         code: code,
         traceId: traceId,
         cause: cause,
       );

  /// The message per field; empty when the error is not about a field.
  final Map<String, String> fieldErrors;
}

/// The backend failed (HTTP 5xx), answered with a status that has no more
/// specific type (409 conflict, 422 business-rule violation, 413, 415…),
/// or sent a response the client could not read.
final class ServerException extends AppException {
  /// Creates a server exception.
  const ServerException({
    String message = 'The server failed to handle the request.',
    int? statusCode,
    String? code,
    String? traceId,
    this.invalidResponse = false,
    this.retryAfter,
    Object? cause,
  }) : super(
         message,
         statusCode: statusCode,
         code: code,
         traceId: traceId,
         cause: cause,
       );

  /// A response that could not be decoded or did not match the expected
  /// shape (a serialization error).
  const ServerException.invalidResponse({
    String message = 'The server response could not be read.',
    int? statusCode,
    Object? cause,
  }) : this(
         message: message,
         statusCode: statusCode,
         invalidResponse: true,
         cause: cause,
       );

  /// Whether the response body could not be read (serialization error).
  final bool invalidResponse;

  /// How long the backend asked the client to wait before trying again
  /// (`Retry-After` on a 429 or 503), or null when it did not say.
  final Duration? retryAfter;
}

/// The request or connection took too long (client timeouts, HTTP 408 and
/// 504).
final class TimeoutException extends AppException {
  /// Creates a timeout exception.
  const TimeoutException({
    String message = 'The request timed out.',
    int? statusCode,
    String? code,
    String? traceId,
    Object? cause,
  }) : super(
         message,
         statusCode: statusCode,
         code: code,
         traceId: traceId,
         cause: cause,
       );
}

/// The request was cancelled by the app (for example the screen closed).
final class CancelledException extends AppException {
  /// Creates a cancelled exception.
  const CancelledException({
    String message = 'The request was cancelled.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Anything the mapper could not classify. Always logged.
final class UnknownException extends AppException {
  /// Creates an unknown exception.
  const UnknownException({
    String message = 'An unexpected error occurred.',
    Object? cause,
  }) : super(message, cause: cause);
}
