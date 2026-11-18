package in.proxycare.shared.error.web;

import in.proxycare.shared.error.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/**
 * Writes a problem response directly to the servlet response, for errors raised outside Spring MVC:
 * security filters, the request-size filter. The body is identical to MVC's.
 */
@Component
public class ProblemResponseWriter {

  private final ProblemFactory problems;
  private final JsonMapper jsonMapper;

  public ProblemResponseWriter(ProblemFactory problems, JsonMapper jsonMapper) {
    this.problems = problems;
    this.jsonMapper = jsonMapper;
  }

  public void write(HttpServletRequest request, HttpServletResponse response, ErrorCode code)
      throws IOException {
    write(response, problems.create(code, request));
  }

  public void write(HttpServletResponse response, ProblemDetail problem) throws IOException {
    if (response.isCommitted()) {
      return; // Too late to change status or body; the original response stands.
    }
    response.resetBuffer();
    response.setStatus(problem.getStatus());
    response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
    response.setCharacterEncoding(StandardCharsets.UTF_8.name());
    jsonMapper.writeValue(response.getOutputStream(), ProblemFactory.toMap(problem));
  }
}
