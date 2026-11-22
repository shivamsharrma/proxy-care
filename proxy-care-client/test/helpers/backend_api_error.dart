import 'fake_http_adapter.dart';

/// The trace ID used by [apiErrorBody] unless a test gives its own.
const String testTraceId = '4bf92f3577b34da6a3ce929d0e0e4736';

/// An error body exactly as the backend sends it: `ApiError{code, message,
/// fieldErrors, meta{traceId, timestamp}}` (`com.proxycare.common.api`).
///
/// The backend omits null members (`@JsonInclude(NON_NULL)`), so
/// [fieldErrors] is left out unless given, and [meta] can be dropped with
/// `includeMeta: false`. `fieldErrors` is an object of field name → one
/// message (the backend keeps the first message per field).
Map<String, Object?> apiErrorBody(
  String? code, {
  String message = 'Backend message',
  Map<String, String>? fieldErrors,
  String? traceId = testTraceId,
  bool includeMeta = true,
}) => {
  'code': ?code,
  'message': message,
  'fieldErrors': ?fieldErrors,
  if (includeMeta)
    'meta': {
      'traceId': ?traceId,
      'timestamp': '2026-11-22T09:30:00Z',
    },
};

/// Responds with an [apiErrorBody] for [code] as `application/json`, with
/// [status].
FakeResponder respondApiError(
  String? code, {
  required int status,
  String message = 'Backend message',
  Map<String, String>? fieldErrors,
  String? traceId = testTraceId,
  Map<String, List<String>> headers = const {},
}) => respondJson(
  apiErrorBody(
    code,
    message: message,
    fieldErrors: fieldErrors,
    traceId: traceId,
  ),
  status: status,
  headers: headers,
);
