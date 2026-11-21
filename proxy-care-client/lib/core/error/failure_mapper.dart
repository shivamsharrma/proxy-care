import 'app_exception.dart';
import 'backend_error_code.dart';
import 'failure.dart';

/// Converts infrastructure exceptions into application failures. Used by
/// repositories (through `guardResult`); the domain never sees an
/// [AppException].
extension AppExceptionToFailure on AppException {
  /// The application failure for this exception.
  AppFailure toFailure() => switch (this) {
    NetworkException(:final message, :final cause) => NetworkFailure(
      message,
      cause: cause,
    ),
    TimeoutException(:final message, :final cause) => NetworkFailure(
      message,
      isTimeout: true,
      cause: cause,
    ),
    UnauthorizedException(:final message, :final code, :final cause) =>
      UnauthorizedFailure(message, code: code, cause: cause),
    ForbiddenException(:final message, :final code, :final cause) =>
      ForbiddenFailure(message, code: code, cause: cause),
    NotFoundException(:final message, :final code, :final cause) =>
      NotFoundFailure(message, code: code, cause: cause),
    ValidationException(
      :final message,
      :final fieldErrors,
      :final code,
      :final cause,
    ) =>
      ValidationFailure(
        message,
        fieldErrors: fieldErrors,
        code: code,
        cause: cause,
      ),
    final ServerException server => _serverFailure(server),
    CancelledException(:final message, :final cause) => CancelledFailure(
      message,
      cause: cause,
    ),
    UnknownException(:final message, :final cause) => UnexpectedFailure(
      message,
      cause: cause,
    ),
  };
}

/// Splits server-side exceptions into the failures screens distinguish.
/// The HTTP status decides first; the backend code decides only what the
/// status leaves open. A 428 (`PRECONDITION_REQUIRED`: the client did not
/// send `If-Match`) is a client bug and stays a [ServerFailure].
AppFailure _serverFailure(ServerException exception) {
  final ServerException(:message, :statusCode, :code, :retryAfter, :cause) =
      exception;
  if (exception.invalidResponse) {
    return ServerFailure(message, statusCode: statusCode, cause: cause);
  }
  switch (statusCode) {
    case 409 || 412:
      return ConflictFailure(message, code: code, cause: cause);
    case 429:
      return RateLimitedFailure(
        message,
        retryAfter: retryAfter,
        code: code,
        cause: cause,
      );
    case 503:
      return ServiceUnavailableFailure(
        message,
        retryAfter: retryAfter,
        code: code,
        cause: cause,
      );
  }
  final isServerSide = statusCode != null && statusCode >= 500;
  return switch (exception.errorCode) {
    BackendErrorCode.businessRuleViolation when !isServerSide =>
      BusinessRuleFailure(message, code: code, cause: cause),
    BackendErrorCode.conflict ||
    BackendErrorCode.preconditionFailed when !isServerSide => ConflictFailure(
      message,
      code: code,
      cause: cause,
    ),
    BackendErrorCode.rateLimited when !isServerSide => RateLimitedFailure(
      message,
      retryAfter: retryAfter,
      code: code,
      cause: cause,
    ),
    BackendErrorCode.serviceUnavailable => ServiceUnavailableFailure(
      message,
      retryAfter: retryAfter,
      code: code,
      cause: cause,
    ),
    _ => ServerFailure(
      message,
      statusCode: statusCode,
      code: code,
      cause: cause,
    ),
  };
}
