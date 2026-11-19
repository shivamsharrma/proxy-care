package com.proxycare.common.error;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.ConstraintViolationException;
import java.io.IOException;
import java.net.URI;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;
import tools.jackson.databind.json.JsonMapper;

/**
 * Turns every error into RFC 9457 problem JSON with a stable {@code code} and the {@code requestId}.
 * Never returns stack traces, SQL, exception class names or exception messages (except an
 * AppException's detail, which is written to be safe).
 *
 * <p>Logging: 4xx logs one WARN line with only code, method and path (exception messages can hold
 * rejected values such as phone numbers); 5xx logs ERROR with the stack trace.
 */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    private static final JsonMapper JSON = new JsonMapper();

    public record FieldViolation(String field, String message) {}

    @ExceptionHandler(AppException.class)
    ResponseEntity<Object> appException(AppException ex, HttpServletRequest request) {
        return respond(ex.code(), ex.detail(), null, request, ex);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    ResponseEntity<Object> constraintViolation(ConstraintViolationException ex, HttpServletRequest request) {
        var errors = ex.getConstraintViolations().stream()
                .map(v -> new FieldViolation(lastNode(v.getPropertyPath().toString()), v.getMessage()))
                .toList();
        return respond(ErrorCode.VALIDATION_FAILED, "Some fields are invalid.", errors, request, ex);
    }

    @ExceptionHandler(AccessDeniedException.class)
    ResponseEntity<Object> accessDenied(AccessDeniedException ex, HttpServletRequest request) {
        return respond(ErrorCode.FORBIDDEN, "You are not allowed to do this.", null, request, ex);
    }

    @ExceptionHandler({OptimisticLockingFailureException.class, DataIntegrityViolationException.class})
    ResponseEntity<Object> conflict(RuntimeException ex, HttpServletRequest request) {
        return respond(ErrorCode.CONFLICT, "The resource was changed or conflicts with existing data.", null, request, ex);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<Object> unexpected(Exception ex, HttpServletRequest request) {
        return respond(ErrorCode.INTERNAL_ERROR, "An unexpected error occurred.", null, request, ex);
    }

    /** Every exception Spring MVC itself raises (404, 405, unreadable body, validation...) ends here. */
    @Override
    protected ResponseEntity<Object> handleExceptionInternal(
            Exception ex, @Nullable Object body, HttpHeaders headers, HttpStatusCode status, WebRequest webRequest) {
        var request = ((NativeWebRequest) webRequest).getNativeRequest(HttpServletRequest.class);
        if (ex instanceof MethodArgumentNotValidException e) {
            var errors = e.getBindingResult().getFieldErrors().stream()
                    .map(f -> new FieldViolation(f.getField(), f.getDefaultMessage()))
                    .toList();
            return respond(ErrorCode.VALIDATION_FAILED, "Some fields are invalid.", errors, request, ex);
        }
        if (ex instanceof HandlerMethodValidationException e) {
            var errors = e.getParameterValidationResults().stream()
                    .flatMap(r -> r.getResolvableErrors().stream()
                            .map(err -> new FieldViolation(r.getMethodParameter().getParameterName(), err.getDefaultMessage())))
                    .toList();
            return respond(ErrorCode.VALIDATION_FAILED, "Some fields are invalid.", errors, request, ex);
        }
        if (ex instanceof HttpMessageNotReadableException) {
            return respond(ErrorCode.MALFORMED_REQUEST, "The request body could not be read.", null, request, ex);
        }
        var code = switch (status.value()) {
            case 400 -> ErrorCode.VALIDATION_FAILED;
            case 404 -> ErrorCode.NOT_FOUND;
            case 405 -> ErrorCode.METHOD_NOT_ALLOWED;
            case 413 -> ErrorCode.PAYLOAD_TOO_LARGE;
            default -> status.is4xxClientError() ? ErrorCode.MALFORMED_REQUEST : ErrorCode.INTERNAL_ERROR;
        };
        // Keep Spring's status (e.g. 415, 406) with the closest code; its detail text is safe.
        return respond(code, status.value(), code.title() + ".", null, request, ex, headers);
    }

    private ResponseEntity<Object> respond(
            ErrorCode code, String detail, @Nullable List<FieldViolation> errors, HttpServletRequest request, Exception ex) {
        return respond(code, code.status().value(), detail, errors, request, ex, HttpHeaders.EMPTY);
    }

    private ResponseEntity<Object> respond(
            ErrorCode code,
            int status,
            String detail,
            @Nullable List<FieldViolation> errors,
            HttpServletRequest request,
            Exception ex,
            HttpHeaders headers) {
        logError(code, status, request, ex);
        var problem = ProblemDetail.forStatusAndDetail(HttpStatusCode.valueOf(status), detail);
        problem.setTitle(code.title());
        problem.setInstance(URI.create(request.getRequestURI()));
        problem.setProperty("code", code.name());
        problem.setProperty("requestId", MDC.get("requestId"));
        if (errors != null) {
            problem.setProperty("errors", errors);
        }
        return ResponseEntity.status(status)
                .headers(headers)
                .contentType(MediaType.APPLICATION_PROBLEM_JSON)
                .body(problem);
    }

    /**
     * Writes the same problem JSON straight to the servlet response, for errors raised in filters
     * (body too large, and 401/403 from Spring Security) before MVC runs.
     */
    public static void writeProblem(
            HttpServletRequest request, HttpServletResponse response, ErrorCode code, String detail)
            throws IOException {
        logError(code, code.status().value(), request, null);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("type", "about:blank");
        body.put("title", code.title());
        body.put("status", code.status().value());
        body.put("detail", detail);
        body.put("instance", request.getRequestURI());
        body.put("code", code.name());
        body.put("requestId", MDC.get("requestId"));
        response.setStatus(code.status().value());
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        JSON.writeValue(response.getOutputStream(), body);
    }

    private static void logError(ErrorCode code, int status, HttpServletRequest request, @Nullable Exception ex) {
        if (status >= 500) {
            log.error("{} {} {}", code, request.getMethod(), request.getRequestURI(), ex);
        } else {
            log.warn("{} {} {}", code, request.getMethod(), request.getRequestURI());
        }
    }

    private static String lastNode(String path) {
        return path.substring(path.lastIndexOf('.') + 1);
    }
}
