/// Failures: expected, recoverable outcomes that repositories and use cases
/// return inside a `Result`, and that presentation turns into user-facing
/// states.
///
/// Two kinds, kept apart:
///
/// * **Application failures** (`NetworkFailure` … `UnexpectedFailure`,
///   including `ConflictFailure`, `BusinessRuleFailure`,
///   `RateLimitedFailure` and `ServiceUnavailableFailure`)
///   describe why an operation could not be completed, independent of the
///   transport. They are created from `AppException`s by repositories.
/// * **Domain failures** extend [DomainFailure]. Features define them for
///   business rules ("the slot is no longer available") and return them
///   from use cases or repositories.
///
/// Pure Dart, so the domain layer can depend on it. [message] is for
/// developers and logs; screens map the failure type to localized copy and
/// never show [message] or [cause] to users.
///
/// Failures implement [Exception] so they can be carried by Riverpod's
/// `AsyncValue.error` (see `Result.getOrThrow`).
library;

import 'backend_error_code.dart';

/// Base of every failure.
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.code, this.cause});

  /// Developer-facing description. Not shown to users.
  final String message;

  /// Machine-readable backend code, as sent. Screens may use it (through
  /// [errorCode]) to pick a more specific message; never the [message].
  final String? code;

  /// [code] as a standard [BackendErrorCode], or null.
  BackendErrorCode? get errorCode => BackendErrorCode.fromWire(code);

  /// What caused it, for logs.
  final Object? cause;

  /// Whether trying the same operation again may succeed.
  bool get isRetryable => false;

  @override
  String toString() {
    final backendCode = code == null ? '' : ' [$code]';
    return '$runtimeType$backendCode: $message';
  }
}

/// The server could not be reached in time or at all. Covers both
/// `NetworkException` and `TimeoutException`.
final class NetworkFailure extends AppFailure {
  /// Creates a network failure.
  const NetworkFailure(super.message, {this.isTimeout = false, super.cause});

  /// Whether the cause was a timeout rather than no connection.
  final bool isTimeout;

  @override
  bool get isRetryable => true;
}

/// The session is missing or expired; the user must sign in again.
final class UnauthorizedFailure extends AppFailure {
  /// Creates an unauthorized failure.
  const UnauthorizedFailure(super.message, {super.code, super.cause});
}

/// The user may not do this.
final class ForbiddenFailure extends AppFailure {
  /// Creates a forbidden failure.
  const ForbiddenFailure(super.message, {super.code, super.cause});
}

/// The thing asked for does not exist (any more).
final class NotFoundFailure extends AppFailure {
  /// Creates a not-found failure.
  const NotFoundFailure(super.message, {super.code, super.cause});
}

/// The input was rejected (HTTP 400, or a 4xx with field errors).
/// [invalidFields] holds only the rejected field names: forms mark those
/// fields and show localized copy. The server's messages never reach it.
final class ValidationFailure extends AppFailure {
  /// Creates a validation failure.
  const ValidationFailure(
    super.message, {
    this.invalidFields = const {},
    super.code,
    super.cause,
  });

  /// Names of the rejected fields; empty when the error is about the
  /// whole request.
  final Set<String> invalidFields;

  /// Whether the backend rejected [field].
  bool hasErrorFor(String field) => invalidFields.contains(field);
}

/// The server failed or answered in a way the app could not use.
final class ServerFailure extends AppFailure {
  /// Creates a server failure.
  const ServerFailure(
    super.message, {
    this.statusCode,
    super.code,
    super.cause,
  });

  /// HTTP status, when known.
  final int? statusCode;

  /// 5xx errors are often temporary.
  @override
  bool get isRetryable => statusCode != null && statusCode! >= 500;
}

/// The data changed on the server meanwhile, or already exists: HTTP 409
/// (`CONCURRENT_MODIFICATION`, `RESOURCE_ALREADY_EXISTS`). A 412 maps here
/// too, though the backend never sends one today. Reload the resource
/// before trying again.
final class ConflictFailure extends AppFailure {
  /// Creates a conflict failure.
  const ConflictFailure(super.message, {super.code, super.cause});

  /// Retrying after a refresh may succeed.
  @override
  bool get isRetryable => true;
}

/// The backend refused the action because of a business rule: any HTTP
/// 422 (`BUSINESS_RULE_VIOLATION` or a feature code). Features turn specific [code]s into their
/// own [DomainFailure]s where a dedicated message is needed.
final class BusinessRuleFailure extends AppFailure {
  /// Creates a business-rule failure.
  const BusinessRuleFailure(super.message, {super.code, super.cause});
}

/// Too many requests (HTTP 429; the backend has no code for it and never
/// sends one today).
final class RateLimitedFailure extends AppFailure {
  /// Creates a rate-limited failure.
  const RateLimitedFailure(
    super.message, {
    this.retryAfter,
    super.code,
    super.cause,
  });

  /// How long to wait before trying again (`Retry-After`), or null when
  /// the backend did not say.
  final Duration? retryAfter;

  @override
  bool get isRetryable => true;
}

/// The service is down or overloaded (HTTP 503,
/// `EXTERNAL_SERVICE_UNAVAILABLE`).
final class ServiceUnavailableFailure extends AppFailure {
  /// Creates a service-unavailable failure.
  const ServiceUnavailableFailure(
    super.message, {
    this.retryAfter,
    super.code,
    super.cause,
  });

  /// How long to wait before trying again (`Retry-After`), or null when
  /// the backend did not say.
  final Duration? retryAfter;

  @override
  bool get isRetryable => true;
}

/// The operation was cancelled by the app. Screens usually ignore it.
final class CancelledFailure extends AppFailure {
  /// Creates a cancelled failure.
  const CancelledFailure(super.message, {super.cause});
}

/// Something unclassified went wrong. It has already been reported.
final class UnexpectedFailure extends AppFailure {
  /// Creates an unexpected failure.
  const UnexpectedFailure(super.message, {super.cause});
}

/// Base for business-rule failures defined by features, e.g.
///
/// ```dart
/// final class SlotUnavailable extends DomainFailure {
///   const SlotUnavailable() : super('The selected slot was taken.');
/// }
/// ```
abstract class DomainFailure extends AppFailure {
  /// Creates a domain failure.
  const DomainFailure(super.message, {super.code, super.cause});
}
