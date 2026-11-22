import 'api_response.dart';

/// A request for one page of a paginated collection, by page number:
/// `?page=<0-based>&size=<n>` (the backend's Spring `Pageable`).
final class PageRequest {
  /// Creates a page request. [page] 0 is the first page.
  const PageRequest({this.page = 0, this.size = defaultSize})
    : assert(page >= 0, 'page must not be negative'),
      assert(size >= 1 && size <= maxSize, 'size must be 1 to 100');

  /// Page size used when none is given (the backend's default too).
  static const int defaultSize = 20;

  /// Largest page size the backend accepts.
  static const int maxSize = 100;

  /// Query parameter that carries [page].
  static const String pageParameter = 'page';

  /// Query parameter that carries [size].
  static const String sizeParameter = 'size';

  /// The 0-based page number.
  final int page;

  /// Maximum number of items, 1 to [maxSize].
  final int size;

  /// The query parameters for this page.
  Map<String, Object> toQuery() => {pageParameter: page, sizeParameter: size};

  /// The request for the page after [current], or null on the last page.
  PageRequest? next(PageResponse<Object?> current) =>
      current.hasNext ? PageRequest(page: current.page + 1, size: size) : null;
}

/// One page of a collection: the backend's `PageResponse`
/// (`{items, page, size, totalElements, totalPages}`).
final class PageResponse<T> {
  /// Creates a page.
  const PageResponse({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  /// The items, in order. Unmodifiable when built by [pageDecoder].
  final List<T> items;

  /// The 0-based page number.
  final int page;

  /// The page size the backend applied.
  final int size;

  /// Number of items across all pages.
  final int totalElements;

  /// Number of pages; 0 for an empty collection.
  final int totalPages;

  /// Whether another page follows.
  bool get hasNext => page + 1 < totalPages;
}

/// Decodes a `PageResponse` body, each item with [decodeItem]. A body of
/// the wrong shape fails as an invalid response (through the parser).
JsonDecoder<PageResponse<T>> pageDecoder<T>(
  T Function(Object? json) decodeItem,
) => (json) {
  final map = json! as Map<Object?, Object?>;
  return PageResponse(
    items: listDecoder(decodeItem)(map['items']),
    page: map['page']! as int,
    size: map['size']! as int,
    totalElements: map['totalElements']! as int,
    totalPages: map['totalPages']! as int,
  );
};

/// Decodes a JSON list with [decodeItem].
JsonDecoder<List<T>> listDecoder<T>(T Function(Object? json) decodeItem) =>
    (json) => List<T>.unmodifiable(
      (json! as List<Object?>).map(decodeItem),
    );
