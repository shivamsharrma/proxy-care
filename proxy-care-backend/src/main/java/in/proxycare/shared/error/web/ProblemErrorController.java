package in.proxycare.shared.error.web;

import in.proxycare.shared.error.ErrorCode;
import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.boot.webmvc.error.ErrorController;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * The servlet container's error page ({@code /error}): errors that never reached Spring MVC, such
 * as a request rejected by the security firewall, get the same problem format as everything else.
 * Replaces Spring Boot's default error controller.
 */
@Controller
public class ProblemErrorController implements ErrorController {

  private final ProblemFactory problems;

  public ProblemErrorController(ProblemFactory problems) {
    this.problems = problems;
  }

  @RequestMapping(
      path = "${server.error.path:/error}",
      produces = {MediaType.APPLICATION_PROBLEM_JSON_VALUE, MediaType.APPLICATION_JSON_VALUE})
  @ResponseBody
  ResponseEntity<ProblemDetail> error(HttpServletRequest request) {
    ErrorCode code = GlobalExceptionHandler.codeFor(status(request));
    HttpHeaders headers = new HttpHeaders();
    return ResponseEntity.status(code.status())
        .headers(headers)
        .contentType(MediaType.APPLICATION_PROBLEM_JSON)
        .body(problems.create(code, request));
  }

  private static int status(HttpServletRequest request) {
    return request.getAttribute(RequestDispatcher.ERROR_STATUS_CODE) instanceof Integer status
        ? status
        : 500;
  }
}
