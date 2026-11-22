import 'dart:convert';

import '../error/serialization.dart';
import 'api_response.dart';

/// Turns a successful HTTP response (2xx) into a typed [ApiResponse].
///
/// A 2xx is a success; the body never carries an error. The backend sends
/// bare JSON (no envelope), so:
///
/// * the whole body goes to the decoder; JSON sent as text is decoded
///   first;
/// * an **empty or null** body (204 No Content) gives the decoder `null`,
///   so a decoder for a nullable or `void` type succeeds and any other
///   fails as an invalid response;
/// * a decoder that throws on an unexpected shape (`TypeError`,
///   `FormatException`, `CheckedFromJsonException`) produces
///   `ServerException.invalidResponse`.
///
/// Response headers are kept on the [ApiResponse] (lower-case names) for
/// `ETag` and `Location`. Error responses (non-2xx) never reach the parser:
/// Dio rejects them and `ErrorMapper` reads their `ApiError` body.
final class ResponseParser {
  /// Creates a parser.
  const ResponseParser();

  /// Parses [body], received with [statusCode] and [headers], into an
  /// [ApiResponse].
  ApiResponse<T> parse<T>(
    Object? body,
    JsonDecoder<T> decode, {
    required int statusCode,
    Map<String, List<String>> headers = const {},
  }) {
    return ApiResponse(
      data: decodeResponse(() => decode(_payload(body))),
      statusCode: statusCode,
      headers: _headers(headers),
    );
  }

  /// The decoded body: null when empty; a JSON body sent with a non-JSON
  /// content type arrives as text and is decoded here.
  static Object? _payload(Object? body) {
    if (body is! String) return body;
    if (body.trim().isEmpty) return null;
    return jsonDecode(body);
  }

  static Map<String, List<String>> _headers(
    Map<String, List<String>> headers,
  ) {
    if (headers.isEmpty) return const {};
    return Map.unmodifiable({
      for (final MapEntry(:key, :value) in headers.entries)
        key.toLowerCase(): List<String>.unmodifiable(value),
    });
  }
}
