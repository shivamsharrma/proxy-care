package in.proxycare.shared.api;

import in.proxycare.shared.error.RequestValidationException;
import java.util.List;
import java.util.function.Function;

/**
 * A request for one page of a keyset-paginated collection (ADR 0012), built from the {@code cursor}
 * and {@code size} query parameters.
 *
 * <pre>{@code
 * PageQuery page = PageQuery.of(cursor, size, 2);   // key: createdAt, id
 * List<Row> rows = repository.findAfter(page.after(), page.fetchSize());
 * return page.toResponse(rows, row -> List.of(row.createdAt().toString(), row.id().toString()));
 * }</pre>
 *
 * @param after key parts of the last item already seen; empty for the first page
 * @param size number of items to return
 */
public record PageQuery(List<String> after, int size) {

  public static final int DEFAULT_SIZE = 20;
  public static final int MAX_SIZE = 100;
  static final String SIZE_PARAMETER = "size";

  public PageQuery {
    after = List.copyOf(after);
    if (size < 1 || size > MAX_SIZE) {
      throw RequestValidationException.of(
          SIZE_PARAMETER, "Range", "must be between 1 and " + MAX_SIZE);
    }
  }

  /**
   * @param cursor the {@code cursor} parameter, or null for the first page
   * @param size the {@code size} parameter, or null for the default
   * @param keyParts how many key parts this collection's cursors hold
   * @throws RequestValidationException for a malformed cursor or a size outside 1-100
   */
  public static PageQuery of(String cursor, Integer size, int keyParts) {
    List<String> after = cursor == null ? List.of() : Cursors.decode(cursor, keyParts);
    return new PageQuery(after, size == null ? DEFAULT_SIZE : size);
  }

  public boolean isFirstPage() {
    return after.isEmpty();
  }

  /** Fetch one more item than requested: its presence says whether another page exists. */
  public int fetchSize() {
    return size + 1;
  }

  /**
   * Builds the response from up to {@link #fetchSize()} items fetched in order.
   *
   * @param keyOf the sort key parts of an item, which become the next cursor
   */
  public <T> PageResponse<T> toResponse(List<T> fetched, Function<T, List<String>> keyOf) {
    boolean hasMore = fetched.size() > size;
    List<T> items = hasMore ? fetched.subList(0, size) : fetched;
    String nextCursor = hasMore ? Cursors.encode(keyOf.apply(items.getLast())) : null;
    return new PageResponse<>(items, new PageMetadata(nextCursor, hasMore, size));
  }
}
