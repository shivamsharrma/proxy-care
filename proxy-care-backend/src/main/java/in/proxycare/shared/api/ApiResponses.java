package in.proxycare.shared.api;

import jakarta.servlet.http.HttpServletRequest;
import java.net.URI;
import org.springframework.http.ResponseEntity;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;
import org.springframework.web.util.UriComponentsBuilder;

/** Standard success responses (ADR 0012), so every controller answers the same way. */
public final class ApiResponses {

  private ApiResponses() {}

  /** 200 with {@code {"data": body}}. */
  public static <T> ResponseEntity<DataResponse<T>> ok(T body) {
    return ResponseEntity.ok(DataResponse.of(body));
  }

  /** 200 with {@code {"data": body}} and the resource's ETag. */
  public static <T> ResponseEntity<DataResponse<T>> ok(T body, long version) {
    return ResponseEntity.ok().eTag(EntityTags.of(version)).body(DataResponse.of(body));
  }

  /**
   * 201 with {@code {"data": body}}, the ETag and {@code Location} set to the current request path
   * plus {@code id} (path-absolute, so it is right behind any proxy).
   */
  public static <T> ResponseEntity<DataResponse<T>> created(Object id, T body, long version) {
    return ResponseEntity.created(locationOf(id))
        .eTag(EntityTags.of(version))
        .body(DataResponse.of(body));
  }

  /** 200 with a page of a collection. */
  public static <T> ResponseEntity<PageResponse<T>> page(PageResponse<T> page) {
    return ResponseEntity.ok(page);
  }

  /** 204 without a body. */
  public static ResponseEntity<Void> noContent() {
    return ResponseEntity.noContent().build();
  }

  static URI locationOf(Object id) {
    HttpServletRequest request =
        ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getRequest();
    return UriComponentsBuilder.fromPath(request.getRequestURI())
        .pathSegment(id.toString())
        .build()
        .toUri();
  }
}
