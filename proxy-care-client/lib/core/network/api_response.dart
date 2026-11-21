/// Converts decoded JSON (a `Map`, `List`, primitive or null) into a typed
/// value, usually `(json) => UserDto.fromJson(json! as Map<String, dynamic>)`.
typedef JsonDecoder<T> = T Function(Object? json);

/// How an endpoint shapes its response body.
enum ResponseFormat {
  /// The API's success body (ADR 0012): `{"data": …}` for a resource,
  /// `{"data": […], "page": {…}}` for a collection. The decoder receives
  /// `data`; `page` becomes [ApiResponse.page].
  envelope,

  /// No envelope: the decoder receives the whole body (third-party or
  /// non-JSON endpoints).
  raw,
}

/// The `page` object of a collection response: where the next page starts.
final class PageMetadata {
  /// Creates page metadata.
  const PageMetadata({
    required this.hasMore,
    required this.size,
    this.nextCursor,
  });

  /// `page.nextCursor`: opaque cursor of the next page, passed back
  /// unchanged; null on the last page.
  final String? nextCursor;

  /// `page.hasMore`: whether another page exists.
  final bool hasMore;

  /// `page.size`: the page size the backend applied.
  final int size;
}

/// A successful (2xx) response: the typed [data] plus what the app needs
/// from the rest of the response.
final class ApiResponse<T> {
  /// Creates a response. [headers] must have lower-case names (as built by
  /// `ResponseParser`).
  const ApiResponse({
    required this.data,
    required this.statusCode,
    this.page,
    this.headers = const {},
  });

  /// The decoded payload.
  final T data;

  /// HTTP status (2xx).
  final int statusCode;

  /// The `page` object of a collection response; null for a single
  /// resource, an empty body or a raw response.
  final PageMetadata? page;

  /// Response headers by lower-case name. Unmodifiable.
  final Map<String, List<String>> headers;

  /// The first value of header [name] (case-insensitive), or null.
  String? header(String name) {
    final values = headers[name.toLowerCase()];
    return values == null || values.isEmpty ? null : values.first;
  }

  /// The `ETag` of a versioned resource, exactly as sent (quotes
  /// included). Store it with the resource and send it back unchanged as
  /// `ApiRequestOptions.ifMatch` when updating it. Opaque: never parse it.
  String? get etag => header('etag');

  /// The `Location` of a created resource (201), a path under `/api/v1`.
  String? get location => header('location');
}
