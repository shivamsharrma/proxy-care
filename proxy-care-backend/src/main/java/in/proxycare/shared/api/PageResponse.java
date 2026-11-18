package in.proxycare.shared.api;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

/**
 * Body of a collection response: {@code {"data": [...], "page": {...}}} (ADR 0012).
 *
 * @param data the items of this page, in order
 * @param page pagination state
 */
@Schema(description = "One page of a collection.")
public record PageResponse<T>(List<T> data, PageMetadata page) {

  public PageResponse {
    data = List.copyOf(data);
  }
}
