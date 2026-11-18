import 'dart:convert';

import '../error/app_exception.dart';
import '../error/serialization.dart';
import 'api_response.dart';

/// Turns a successful HTTP response (2xx) into a typed [ApiResponse].
///
/// A 2xx is a success (ADR 0012); the body never carries an error.
///
/// * **Envelope** ([ResponseFormat.envelope]): a JSON object with `data`,
///   handed to the decoder, and for a collection a `page` object
///   (`nextCursor`, `hasMore`, `size`), returned as [ApiResponse.page]. A
///   body without `data`, or with a malformed `page`, is an invalid
///   response.
/// * **Raw** ([ResponseFormat.raw]): the whole body goes to the decoder.
/// * **Empty or null** body (204 No Content): the decoder gets `null`, so a
///   decoder for a nullable or `void` type succeeds and any other fails as
///   an invalid response.
/// * A decoder that throws on an unexpected shape (`TypeError`,
///   `FormatException`, `CheckedFromJsonException`) produces
///   `ServerException.invalidResponse`.
///
/// Response headers are kept on the [ApiResponse] (lower-case names) for
/// `ETag` and `Location`. Error responses (non-2xx) never reach the parser:
/// Dio rejects them and `ErrorMapper` reads their problem details.
final class ResponseParser {
  /// Creates a parser.
  const ResponseParser();

  /// Parses [body], received with [statusCode] and [headers], into an
  /// [ApiResponse].
  ApiResponse<T> parse<T>(
    Object? body,
    JsonDecoder<T> decode, {
    required int statusCode,
    ResponseFormat format = ResponseFormat.envelope,
    Map<String, List<String>> headers = const {},
  }) {
    final responseHeaders = _headers(headers);
    final payload = _isEmpty(body) ? null : body;

    if (format == ResponseFormat.raw || payload == null) {
      return ApiResponse(
        data: decodeResponse(() => decode(payload)),
        statusCode: statusCode,
        headers: responseHeaders,
      );
    }

    final decoded = _decodeJsonText(payload);
    if (decoded is! Map<Object?, Object?> || !decoded.containsKey('data')) {
      throw ServerException.invalidResponse(
        message: 'Expected a {"data": …} response body.',
        statusCode: statusCode,
      );
    }

    return ApiResponse(
      data: decodeResponse(() => decode(decoded['data'])),
      statusCode: statusCode,
      page: _page(decoded['page'], statusCode),
      headers: responseHeaders,
    );
  }

  /// A JSON body sent with a non-JSON content type arrives as text.
  static Object? _decodeJsonText(Object body) {
    if (body is! String) return body;
    return decodeResponse(() => jsonDecode(body));
  }

  static bool _isEmpty(Object? body) =>
      body == null || (body is String && body.trim().isEmpty);

  /// The `page` object, or null when the response has none.
  static PageMetadata? _page(Object? value, int statusCode) {
    if (value == null) return null;
    if (value is Map<Object?, Object?>) {
      final nextCursor = value['nextCursor'];
      final hasMore = value['hasMore'];
      final size = value['size'];
      if (nextCursor is String? && hasMore is bool && size is int) {
        return PageMetadata(
          nextCursor: nextCursor,
          hasMore: hasMore,
          size: size,
        );
      }
    }
    throw ServerException.invalidResponse(
      message: 'Malformed page object.',
      statusCode: statusCode,
    );
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
