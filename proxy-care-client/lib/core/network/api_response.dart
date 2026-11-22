/// Converts decoded JSON (a `Map`, `List`, primitive or null) into a typed
/// value, usually `(json) => UserDto.fromJson(json! as Map<String, dynamic>)`.
typedef JsonDecoder<T> = T Function(Object? json);

/// A successful (2xx) response: the typed [data] plus what the app needs
/// from the rest of the response.
final class ApiResponse<T> {
  /// Creates a response. [headers] must have lower-case names (as built by
  /// `ResponseParser`).
  const ApiResponse({
    required this.data,
    required this.statusCode,
    this.headers = const {},
  });

  /// The decoded payload.
  final T data;

  /// HTTP status (2xx).
  final int statusCode;

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
