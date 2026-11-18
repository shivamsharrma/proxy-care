package in.proxycare.shared.error.web;

import in.proxycare.shared.api.ApiProperties;
import in.proxycare.shared.error.ErrorCode;
import in.proxycare.shared.error.FieldValidationError;
import in.proxycare.shared.error.ProxyCareException;
import io.github.resilience4j.bulkhead.BulkheadFullException;
import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.ratelimiter.RequestNotPermitted;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import jakarta.validation.ElementKind;
import jakarta.validation.Path;
import java.net.http.HttpTimeoutException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.TypeMismatchException;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.MessageSourceResolvable;
import org.springframework.core.NestedExceptionUtils;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.dao.TransientDataAccessResourceException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.AuthenticationTrustResolver;
import org.springframework.security.authentication.AuthenticationTrustResolverImpl;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.TransactionTimedOutException;
import org.springframework.validation.FieldError;
import org.springframework.validation.ObjectError;
import org.springframework.validation.method.ParameterErrors;
import org.springframework.validation.method.ParameterValidationResult;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.DatabindException;
import tools.jackson.databind.exc.UnrecognizedPropertyException;

/**
 * Turns every exception that reaches Spring MVC into a problem response (ADR 0012).
 *
 * <p>Details sent to clients are always this application's own sentences: messages from Jackson,
 * binding, the database or vendors can contain class names, SQL or the rejected values, so they are
 * never echoed. Unexpected errors are logged with their stack trace under the response's {@code
 * traceId}.
 */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

  private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

  private static final AuthenticationTrustResolver TRUST_RESOLVER =
      new AuthenticationTrustResolverImpl();

  private final ProblemFactory problems;
  private final ApiProperties apiProperties;
  private final ObjectProvider<CircuitBreakerRegistry> circuitBreakers;

  public GlobalExceptionHandler(
      ProblemFactory problems,
      ApiProperties apiProperties,
      ObjectProvider<CircuitBreakerRegistry> circuitBreakers) {
    this.problems = problems;
    this.apiProperties = apiProperties;
    this.circuitBreakers = circuitBreakers;
  }

  // ---- Application exceptions ---------------------------------------------------------------

  @ExceptionHandler(ProxyCareException.class)
  ResponseEntity<ProblemDetail> handleProxyCare(
      ProxyCareException exception, HttpServletRequest request) {
    if (exception.code().status() >= 500) {
      logServerError(exception, request);
    }
    HttpHeaders headers = new HttpHeaders();
    exception.retryAfter().ifPresent(retryAfter -> setRetryAfter(headers, retryAfter));
    return respond(
        problems.create(exception.code(), exception.getMessage(), exception.errors(), request),
        headers);
  }

  @ExceptionHandler(ConstraintViolationException.class)
  ResponseEntity<ProblemDetail> handleConstraintViolation(
      ConstraintViolationException exception, HttpServletRequest request) {
    List<FieldValidationError> errors =
        exception.getConstraintViolations().stream().map(GlobalExceptionHandler::toError).toList();
    return validationProblem(errors, request);
  }

  // ---- Security inside MVC (method security); filters use ProblemSecurityHandlers -----------

  @ExceptionHandler(AuthenticationException.class)
  ResponseEntity<ProblemDetail> handleAuthentication(
      AuthenticationException exception, HttpServletRequest request) {
    return unauthenticated(request);
  }

  @ExceptionHandler(AccessDeniedException.class)
  ResponseEntity<ProblemDetail> handleAccessDenied(
      AccessDeniedException exception, HttpServletRequest request) {
    Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
    if (authentication == null || TRUST_RESOLVER.isAnonymous(authentication)) {
      return unauthenticated(request);
    }
    return respond(problems.create(ErrorCode.FORBIDDEN, request), new HttpHeaders());
  }

  // ---- Persistence --------------------------------------------------------------------------

  /**
   * A concurrent update won. With If-Match the client asked for exactly this check, so it is a
   * failed precondition (412); without it, a conflict (409).
   */
  @ExceptionHandler(OptimisticLockingFailureException.class)
  ResponseEntity<ProblemDetail> handleOptimisticLocking(
      OptimisticLockingFailureException exception, HttpServletRequest request) {
    ErrorCode code =
        request.getHeader(HttpHeaders.IF_MATCH) != null
            ? ErrorCode.PRECONDITION_FAILED
            : ErrorCode.CONFLICT;
    return respond(problems.create(code, request), new HttpHeaders());
  }

  @ExceptionHandler(DataIntegrityViolationException.class)
  ResponseEntity<ProblemDetail> handleIntegrityViolation(
      DataIntegrityViolationException exception, HttpServletRequest request) {
    log.debug("Integrity violation [{}]", problems.traceId(request), exception);
    return respond(
        problems.create(
            ErrorCode.CONFLICT, "The request conflicts with existing data.", List.of(), request),
        new HttpHeaders());
  }

  @ExceptionHandler({
    QueryTimeoutException.class,
    CannotAcquireLockException.class,
    TransactionTimedOutException.class,
    DataAccessResourceFailureException.class,
    TransientDataAccessResourceException.class
  })
  ResponseEntity<ProblemDetail> handleDatabaseUnavailable(
      Exception exception, HttpServletRequest request) {
    logServerError(exception, request);
    return serviceUnavailable(apiProperties.defaultRetryAfter(), request);
  }

  // ---- Resilience4j -------------------------------------------------------------------------

  @ExceptionHandler(CallNotPermittedException.class)
  ResponseEntity<ProblemDetail> handleCircuitOpen(
      CallNotPermittedException exception, HttpServletRequest request) {
    Duration retryAfter =
        openStateWait(exception.getCausingCircuitBreakerName())
            .orElse(apiProperties.defaultRetryAfter());
    return serviceUnavailable(retryAfter, request);
  }

  @ExceptionHandler(BulkheadFullException.class)
  ResponseEntity<ProblemDetail> handleBulkheadFull(
      BulkheadFullException exception, HttpServletRequest request) {
    return serviceUnavailable(apiProperties.defaultRetryAfter(), request);
  }

  @ExceptionHandler(RequestNotPermitted.class)
  ResponseEntity<ProblemDetail> handleRateLimited(
      RequestNotPermitted exception, HttpServletRequest request) {
    HttpHeaders headers = new HttpHeaders();
    setRetryAfter(headers, apiProperties.defaultRetryAfter());
    return respond(problems.create(ErrorCode.RATE_LIMITED, request), headers);
  }

  // ---- Vendor calls that escaped their adapter ----------------------------------------------

  /** Safety net: adapters should translate to UpstreamException. Vendor bodies are never sent. */
  @ExceptionHandler(RestClientException.class)
  ResponseEntity<ProblemDetail> handleRestClient(
      RestClientException exception, HttpServletRequest request) {
    logServerError(exception, request);
    boolean timedOut =
        exception instanceof ResourceAccessException
            && NestedExceptionUtils.getMostSpecificCause(exception) instanceof HttpTimeoutException;
    ErrorCode code = timedOut ? ErrorCode.UPSTREAM_TIMEOUT : ErrorCode.UPSTREAM_ERROR;
    return respond(problems.create(code, request), new HttpHeaders());
  }

  // ---- Anything else ------------------------------------------------------------------------

  @ExceptionHandler(Exception.class)
  ResponseEntity<ProblemDetail> handleUnexpected(Exception exception, HttpServletRequest request) {
    logServerError(exception, request);
    return respond(problems.create(ErrorCode.INTERNAL_ERROR, request), new HttpHeaders());
  }

  // ---- Spring MVC's own exceptions ----------------------------------------------------------

  @Override
  protected ResponseEntity<Object> handleMethodArgumentNotValid(
      MethodArgumentNotValidException exception,
      HttpHeaders headers,
      HttpStatusCode status,
      WebRequest request) {
    List<FieldValidationError> errors = new ArrayList<>();
    for (ObjectError error : exception.getBindingResult().getAllErrors()) {
      errors.add(toError(error));
    }
    return asObject(validationProblem(errors, servletRequest(request)));
  }

  @Override
  protected ResponseEntity<Object> handleHandlerMethodValidationException(
      HandlerMethodValidationException exception,
      HttpHeaders headers,
      HttpStatusCode status,
      WebRequest request) {
    List<FieldValidationError> errors = new ArrayList<>();
    for (ParameterValidationResult result : exception.getParameterValidationResults()) {
      if (result instanceof ParameterErrors beanErrors) {
        beanErrors.getAllErrors().forEach(error -> errors.add(toError(error)));
      } else {
        String parameter = result.getMethodParameter().getParameterName();
        for (MessageSourceResolvable error : result.getResolvableErrors()) {
          errors.add(
              new FieldValidationError(
                  parameter == null ? "" : parameter, constraintCode(error), message(error)));
        }
      }
    }
    return asObject(validationProblem(errors, servletRequest(request)));
  }

  @Override
  protected ResponseEntity<Object> handleHttpMessageNotReadable(
      HttpMessageNotReadableException exception,
      HttpHeaders headers,
      HttpStatusCode status,
      WebRequest request) {
    HttpServletRequest servletRequest = servletRequest(request);
    if (RequestSizeLimitFilter.isTooLarge(exception)) {
      return asObject(
          respond(problems.create(ErrorCode.PAYLOAD_TOO_LARGE, servletRequest), new HttpHeaders()));
    }
    List<FieldValidationError> errors =
        NestedExceptionUtils.getMostSpecificCause(exception) instanceof DatabindException databind
            ? jsonErrors(databind)
            : List.of();
    return asObject(
        respond(
            problems.create(
                ErrorCode.MALFORMED_REQUEST,
                "The request body is not valid JSON or does not match the expected structure.",
                errors,
                servletRequest),
            new HttpHeaders()));
  }

  @Override
  protected ResponseEntity<Object> handleMissingServletRequestParameter(
      MissingServletRequestParameterException exception,
      HttpHeaders headers,
      HttpStatusCode status,
      WebRequest request) {
    FieldValidationError error =
        new FieldValidationError(
            exception.getParameterName(), "Required", "required parameter is missing");
    return asObject(
        respond(
            problems.create(
                ErrorCode.MALFORMED_REQUEST,
                "A required parameter is missing.",
                List.of(error),
                servletRequest(request)),
            new HttpHeaders()));
  }

  @Override
  protected ResponseEntity<Object> handleTypeMismatch(
      TypeMismatchException exception,
      HttpHeaders headers,
      HttpStatusCode status,
      WebRequest request) {
    String name = exception.getPropertyName() == null ? "" : exception.getPropertyName();
    FieldValidationError error =
        new FieldValidationError(name, "InvalidFormat", "has an invalid value");
    return asObject(
        respond(
            problems.create(
                ErrorCode.MALFORMED_REQUEST,
                "A parameter has an invalid value.",
                List.of(error),
                servletRequest(request)),
            new HttpHeaders()));
  }

  /**
   * Every other Spring MVC exception (unsupported method or media type, not acceptable, no handler,
   * async timeout...): the status Spring chose decides the code. Spring's headers, such as {@code
   * Allow} and {@code Accept}, are kept.
   */
  @Override
  protected ResponseEntity<Object> handleExceptionInternal(
      Exception exception,
      Object body,
      HttpHeaders headers,
      HttpStatusCode statusCode,
      WebRequest request) {
    ErrorCode code = codeFor(statusCode.value());
    if (code == ErrorCode.SERVICE_UNAVAILABLE) {
      setRetryAfter(headers, apiProperties.defaultRetryAfter());
    }
    if (code.status() >= 500) {
      logServerError(exception, servletRequest(request));
    }
    HttpHeaders kept = new HttpHeaders();
    kept.putAll(headers);
    return asObject(respond(problems.create(code, servletRequest(request)), kept));
  }

  // ---- Helpers ------------------------------------------------------------------------------

  static ErrorCode codeFor(int status) {
    for (ErrorCode code : ErrorCode.values()) {
      if (code.status() == status) {
        return code;
      }
    }
    return status >= 500 ? ErrorCode.INTERNAL_ERROR : ErrorCode.MALFORMED_REQUEST;
  }

  private ResponseEntity<ProblemDetail> validationProblem(
      List<FieldValidationError> errors, HttpServletRequest request) {
    return respond(
        problems.create(
            ErrorCode.VALIDATION_ERROR,
            ErrorCode.VALIDATION_ERROR.defaultDetail(),
            errors,
            request),
        new HttpHeaders());
  }

  private ResponseEntity<ProblemDetail> unauthenticated(HttpServletRequest request) {
    HttpHeaders headers = new HttpHeaders();
    headers.set(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
    return respond(problems.create(ErrorCode.UNAUTHENTICATED, request), headers);
  }

  private ResponseEntity<ProblemDetail> serviceUnavailable(
      Duration retryAfter, HttpServletRequest request) {
    HttpHeaders headers = new HttpHeaders();
    setRetryAfter(headers, retryAfter);
    return respond(problems.create(ErrorCode.SERVICE_UNAVAILABLE, request), headers);
  }

  private static ResponseEntity<ProblemDetail> respond(ProblemDetail problem, HttpHeaders headers) {
    return ResponseEntity.status(problem.getStatus()).headers(headers).body(problem);
  }

  @SuppressWarnings({"unchecked", "rawtypes"})
  private static ResponseEntity<Object> asObject(ResponseEntity<ProblemDetail> response) {
    return (ResponseEntity) response;
  }

  /** Retry-After in whole seconds, rounded up, at least 1. */
  static void setRetryAfter(HttpHeaders headers, Duration retryAfter) {
    long seconds = Math.max(1, (retryAfter.toMillis() + 999) / 1000);
    headers.set(HttpHeaders.RETRY_AFTER, Long.toString(seconds));
  }

  private Optional<Duration> openStateWait(String circuitBreakerName) {
    CircuitBreakerRegistry registry = circuitBreakers.getIfAvailable();
    if (registry == null || circuitBreakerName == null) {
      return Optional.empty();
    }
    return registry
        .find(circuitBreakerName)
        .map(breaker ->
            Duration.ofMillis(
                breaker.getCircuitBreakerConfig().getWaitIntervalFunctionInOpenState().apply(1)));
  }

  private void logServerError(Exception exception, HttpServletRequest request) {
    log.error("Request failed [traceId={}]", problems.traceId(request), exception);
  }

  private static HttpServletRequest servletRequest(WebRequest request) {
    return ((NativeWebRequest) request).getNativeRequest(HttpServletRequest.class);
  }

  private static FieldValidationError toError(ObjectError error) {
    if (error instanceof FieldError fieldError) {
      if (fieldError.isBindingFailure()) {
        // Binding failure messages contain class names and the rejected value.
        return new FieldValidationError(
            fieldError.getField(), "InvalidFormat", "has an invalid value");
      }
      return new FieldValidationError(fieldError.getField(), constraintCode(error), message(error));
    }
    return new FieldValidationError("", constraintCode(error), message(error));
  }

  private static FieldValidationError toError(ConstraintViolation<?> violation) {
    return new FieldValidationError(
        propertyPath(violation.getPropertyPath()),
        violation.getConstraintDescriptor().getAnnotation().annotationType().getSimpleName(),
        violation.getMessage());
  }

  /** The most general message code, which is the constraint name ("Max" in "Max.request.age"). */
  private static String constraintCode(MessageSourceResolvable error) {
    String[] codes = error.getCodes();
    return codes == null || codes.length == 0 ? "Invalid" : codes[codes.length - 1];
  }

  private static String message(MessageSourceResolvable error) {
    return error.getDefaultMessage() == null ? "is invalid" : error.getDefaultMessage();
  }

  /** "purposes[0].name", without method and parameter names from method validation. */
  private static String propertyPath(Path path) {
    StringBuilder result = new StringBuilder();
    for (Path.Node node : path) {
      if (node.getKind() == ElementKind.METHOD
          || node.getKind() == ElementKind.CONSTRUCTOR
          || node.getKind() == ElementKind.PARAMETER
          || node.getKind() == ElementKind.RETURN_VALUE) {
        continue;
      }
      if (node.isInIterable()) {
        Object position = node.getIndex() != null ? node.getIndex() : node.getKey();
        result.append('[').append(position).append(']');
      }
      if (node.getName() != null) {
        if (!result.isEmpty()) {
          result.append('.');
        }
        result.append(node.getName());
      }
    }
    return result.toString();
  }

  /** Where in the JSON body reading failed: "patient.age" or "purposes[2]". */
  private static List<FieldValidationError> jsonErrors(DatabindException exception) {
    StringBuilder path = new StringBuilder();
    for (JacksonException.Reference reference : exception.getPath()) {
      if (reference.getPropertyName() != null) {
        if (!path.isEmpty()) {
          path.append('.');
        }
        path.append(reference.getPropertyName());
      } else if (reference.getIndex() >= 0) {
        path.append('[').append(reference.getIndex()).append(']');
      }
    }
    if (path.isEmpty()) {
      return List.of();
    }
    return exception instanceof UnrecognizedPropertyException
        ? List.of(
            new FieldValidationError(path.toString(), "UnknownProperty", "is not a known property"))
        : List.of(
            new FieldValidationError(path.toString(), "InvalidFormat", "has an invalid value"));
  }
}
