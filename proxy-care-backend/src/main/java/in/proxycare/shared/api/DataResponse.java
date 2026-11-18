package in.proxycare.shared.api;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * Body of a single-resource response: {@code {"data": {...}}} (ADR 0012).
 *
 * @param data the resource
 */
@Schema(description = "A single resource.")
public record DataResponse<T>(T data) {

  public static <T> DataResponse<T> of(T data) {
    return new DataResponse<>(data);
  }
}
