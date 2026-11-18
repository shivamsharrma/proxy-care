package in.proxycare.shared.error.web;

import io.micrometer.tracing.Span;
import io.micrometer.tracing.Tracer;
import jakarta.servlet.http.HttpServletRequest;
import java.util.UUID;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/**
 * The {@code traceId} of a problem response: the current trace's id, so support can find the
 * request in traces and logs (ADR 0006). If no trace is active, a random id is generated once per
 * request and reused for every problem written for it.
 */
@Component
public class TraceIdProvider {

  private static final String ATTRIBUTE = TraceIdProvider.class.getName() + ".traceId";
  private static final String INVALID_TRACE_ID = "00000000000000000000000000000000";

  private final ObjectProvider<Tracer> tracer;

  public TraceIdProvider(ObjectProvider<Tracer> tracer) {
    this.tracer = tracer;
  }

  public String traceId(HttpServletRequest request) {
    if (request.getAttribute(ATTRIBUTE) instanceof String known) {
      return known;
    }
    String traceId = currentTraceId();
    request.setAttribute(ATTRIBUTE, traceId);
    return traceId;
  }

  private String currentTraceId() {
    Tracer current = tracer.getIfAvailable();
    Span span = current == null ? null : current.currentSpan();
    if (span != null) {
      String id = span.context().traceId();
      if (id != null && !id.isBlank() && !INVALID_TRACE_ID.equals(id)) {
        return id;
      }
    }
    return UUID.randomUUID().toString().replace("-", "");
  }
}
