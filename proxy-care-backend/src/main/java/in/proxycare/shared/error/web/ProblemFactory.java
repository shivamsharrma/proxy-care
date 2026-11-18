package in.proxycare.shared.error.web;

import in.proxycare.shared.error.ErrorCode;
import in.proxycare.shared.error.FieldValidationError;
import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.http.HttpServletRequest;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.stereotype.Component;
import org.springframework.web.util.UriUtils;

/**
 * Builds every problem response body (ADR 0012), whichever layer produced the error: {@code type},
 * {@code title}, {@code status}, {@code detail}, {@code instance}, {@code code}, {@code traceId},
 * {@code timestamp} and, for field problems, {@code errors}.
 */
@Component
public class ProblemFactory {

  private final Clock clock;
  private final TraceIdProvider traceIds;

  public ProblemFactory(Clock clock, TraceIdProvider traceIds) {
    this.clock = clock;
    this.traceIds = traceIds;
  }

  public ProblemDetail create(ErrorCode code, HttpServletRequest request) {
    return create(code, code.defaultDetail(), List.of(), request);
  }

  public ProblemDetail create(
      ErrorCode code,
      String detail,
      List<FieldValidationError> errors,
      HttpServletRequest request) {
    ProblemDetail problem =
        ProblemDetail.forStatusAndDetail(HttpStatusCode.valueOf(code.status()), detail);
    problem.setType(URI.create(code.type()));
    problem.setTitle(code.title());
    problem.setInstance(instance(request));
    problem.setProperty("code", code.name());
    problem.setProperty("traceId", traceIds.traceId(request));
    problem.setProperty("timestamp", clock.instant());
    if (!errors.isEmpty()) {
      problem.setProperty("errors", List.copyOf(errors));
    }
    return problem;
  }

  /** The request's trace id, for log lines that must match the response. */
  public String traceId(HttpServletRequest request) {
    return traceIds.traceId(request);
  }

  /**
   * The body as an ordered map, for writers outside Spring MVC (security filters, the error page),
   * matching what MVC writes for a {@link ProblemDetail}.
   */
  public static Map<String, Object> toMap(ProblemDetail problem) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("type", problem.getType().toString());
    body.put("title", problem.getTitle());
    body.put("status", problem.getStatus());
    body.put("detail", problem.getDetail());
    body.put("instance", problem.getInstance() == null ? null : problem.getInstance().toString());
    if (problem.getProperties() != null) {
      body.putAll(problem.getProperties());
    }
    return body;
  }

  /** The request path without the query string, which may hold personal data. */
  private static URI instance(HttpServletRequest request) {
    // On the container's error page the original path is in a request attribute.
    Object original = request.getAttribute(RequestDispatcher.ERROR_REQUEST_URI);
    String path = original instanceof String uri ? uri : request.getRequestURI();
    try {
      return URI.create(path);
    } catch (IllegalArgumentException notAValidUri) {
      return URI.create(UriUtils.encodePath(path, StandardCharsets.UTF_8));
    }
  }
}
