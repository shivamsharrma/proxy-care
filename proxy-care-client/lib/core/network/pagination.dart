import '../error/app_exception.dart';
import 'api_response.dart';

/// A request for one page of a cursor-paginated collection (ADR 0012):
/// `?cursor=<opaque>&size=<n>`.
final class PageRequest {
  /// Creates a page request. A null [cursor] asks for the first page.
  const PageRequest({this.cursor, this.size = defaultSize})
    : assert(size >= 1 && size <= maxSize, 'size must be 1 to 100');

  /// Page size used when none is given (the backend's default too).
  static const int defaultSize = 20;

  /// Largest page size the backend accepts; a larger one is a 422.
  static const int maxSize = 100;

  /// Query parameter that carries [cursor].
  static const String cursorParameter = 'cursor';

  /// Query parameter that carries [size].
  static const String sizeParameter = 'size';

  /// Where to continue: an opaque cursor from `page.nextCursor`, passed
  /// back unchanged; null for the first page.
  final String? cursor;

  /// Maximum number of items, 1 to [maxSize].
  final int size;

  /// The query parameters for this page.
  Map<String, Object> toQuery() => {
    sizeParameter: size,
    cursorParameter: ?cursor,
  };

  /// The request for the page after [page], or null on the last page.
  PageRequest? next(CursorPage<Object?> page) => switch (page) {
    CursorPage(hasMore: true, :final nextCursor?) => PageRequest(
      cursor: nextCursor,
      size: size,
    ),
    _ => null,
  };
}

/// One page of items and where the next page starts.
final class CursorPage<T> {
  /// Creates a page. [hasMore] requires a [nextCursor].
  const CursorPage({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  }) : assert(!hasMore || nextCursor != null, 'hasMore needs a nextCursor');

  /// Builds a page from a collection response: `data` holds the items and
  /// `page` says whether and where the next page starts.
  ///
  /// Throws `ServerException.invalidResponse` when the response has no
  /// `page` object. A `hasMore: true` without a cursor is read as the last
  /// page, since there is no way to ask for the next one.
  factory CursorPage.fromResponse(ApiResponse<List<T>> response) {
    final page = response.page;
    if (page == null) {
      throw ServerException.invalidResponse(
        message: 'Expected a collection response with a page object.',
        statusCode: response.statusCode,
      );
    }
    final cursor = page.nextCursor;
    final next = cursor != null && cursor.isNotEmpty ? cursor : null;
    return CursorPage(
      items: response.data,
      nextCursor: next,
      hasMore: page.hasMore && next != null,
    );
  }

  /// The items, in order. Unmodifiable when built by [CursorPage.fromResponse]
  /// from a decoded list.
  final List<T> items;

  /// Cursor of the next page; null on the last page.
  final String? nextCursor;

  /// Whether another page follows.
  final bool hasMore;
}

/// Decodes a JSON list with [decodeItem], for collection `data`.
JsonDecoder<List<T>> listDecoder<T>(T Function(Object? json) decodeItem) =>
    (json) => List<T>.unmodifiable(
      (json! as List<Object?>).map(decodeItem),
    );
