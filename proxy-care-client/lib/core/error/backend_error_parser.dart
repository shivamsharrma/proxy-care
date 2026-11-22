import 'dart:convert';

/// The parts of a backend error response the app relies on.
///
/// The app branches on [code] only. [message] and the [fieldErrors] texts
/// are English developer text that can echo personal data: parsed, but
/// never put on an `AppException` message, never shown and never logged.
final class BackendError {
  /// Creates a parsed backend error.
  const BackendError({
    this.code,
    this.message,
    this.fieldErrors = const {},
    this.traceId,
  });

  /// `code`: stable machine-readable identifier.
  final String? code;

  /// `message`: technical English text.
  final String? message;

  /// `fieldErrors`: field name (a property path such as `patient.age`) →
  /// its single message, as the backend's `FieldErrors.from` builds it.
  final Map<String, String> fieldErrors;

  /// `meta.traceId`: identifies the request in the backend's logs.
  final String? traceId;
}

/// Reads the backend's error body (`com.proxycare.common.api.ApiError`):
///
/// ```json
/// {
///   "code": "VALIDATION_FAILED",
///   "message": "Validation failed",
///   "fieldErrors": {"age": "must be less than or equal to 120"},
///   "meta": {"traceId": "4bf92f35…", "timestamp": "2026-11-22T09:30:00Z"}
/// }
/// ```
///
/// Null members are omitted by the backend. Independent of any feature
/// DTO: it reads raw JSON.
abstract final class BackendErrorParser {
  /// Parses [body]: a decoded JSON map or a JSON string. Never throws:
  /// anything else (an HTML error page, an empty body) yields an empty
  /// [BackendError], so the HTTP status alone classifies the error, and a
  /// malformed member is skipped while the rest is kept.
  static BackendError parse(Object? body) {
    final json = _asMap(body);
    if (json == null) return const BackendError();
    final meta = json['meta'];
    return BackendError(
      code: _string(json['code']),
      message: _string(json['message']),
      fieldErrors: _fieldErrors(json['fieldErrors']),
      traceId: meta is Map<Object?, Object?> ? _string(meta['traceId']) : null,
    );
  }

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

  /// The `fieldErrors` object (field → one message). Entries whose
  /// message is not a string are skipped.
  static Map<String, String> _fieldErrors(Object? value) {
    if (value is! Map<Object?, Object?>) return const {};
    final errors = <String, String>{};
    for (final MapEntry(key: field, value: text) in value.entries) {
      final message = _string(text);
      if (field is String && message != null) errors[field] = message;
    }
    return errors;
  }
}
