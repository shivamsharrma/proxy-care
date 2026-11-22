package com.proxycare.common.exception.handler;

import com.proxycare.common.api.ApiError;
import com.proxycare.common.exception.AppException;
import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.security.SecurityMessages;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Stream;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.FieldError;
import org.springframework.validation.method.ParameterValidationResult;
import org.springframework.web.ErrorResponse;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.NoHandlerFoundException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/** Maps every exception a controller throws to an ErrorCode and a safe message. Internals never reach the client. */
@RestControllerAdvice
@RequiredArgsConstructor
@Slf4j
public class GlobalExceptionHandler {

    private static final String VALIDATION_FAILED = "Validation failed";
    private static final String INVALID_REQUEST = "Invalid request";
    private static final String METHOD_NOT_SUPPORTED = "HTTP method not supported";
    private static final String UNSUPPORTED_MEDIA_TYPE = "Unsupported media type";
    private static final String CONCURRENT_MODIFICATION = "Resource was modified by another request. Please retry.";
    private static final String CONFLICTS_WITH_EXISTING_DATA = "The requested operation conflicts with existing data";
    private static final String NOT_FOUND = "Resource not found";
    private static final String UNEXPECTED_ERROR = "An unexpected error occurred";
    private static final String UNNAMED_PARAMETER = "parameter";

    private final ApiErrorFactory apiErrorFactory;

    @ExceptionHandler(AppException.class)
    public ResponseEntity<ApiError> handleAppException(AppException ex) {
        logAppException(ex);
        return respond(ex.getErrorCode(), ex.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleInvalidBody(MethodArgumentNotValidException ex) {
        Map<String, String> fieldErrors = FieldErrors.from(
                ex.getBindingResult().getFieldErrors().stream(), FieldError::getField, FieldError::getDefaultMessage);
        return respond(ErrorCode.VALIDATION_FAILED, VALIDATION_FAILED, fieldErrors);
    }

    @ExceptionHandler(HandlerMethodValidationException.class)
    public ResponseEntity<ApiError> handleInvalidParameters(HandlerMethodValidationException ex) {
        Stream<ParameterFailure> parameterFailures = ex.getParameterValidationResults().stream().flatMap(GlobalExceptionHandler::parameterFailures);
        Map<String, String> fieldErrors = FieldErrors.from(parameterFailures, ParameterFailure::parameter, ParameterFailure::message);
        return respond(ErrorCode.VALIDATION_FAILED, VALIDATION_FAILED, fieldErrors);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiError> handleConstraintViolation(ConstraintViolationException ex) {
        Map<String, String> fieldErrors = FieldErrors.from(
                ex.getConstraintViolations().stream(),
                violation -> violation.getPropertyPath().toString(),
                ConstraintViolation::getMessage);
        return respond(ErrorCode.VALIDATION_FAILED, VALIDATION_FAILED, fieldErrors);
    }

    @ExceptionHandler({
        HttpMessageNotReadableException.class,
        MissingServletRequestParameterException.class,
        MethodArgumentTypeMismatchException.class
    })
    public ResponseEntity<ApiError> handleMalformedRequest(Exception ex) {
        return respond(ErrorCode.MALFORMED_REQUEST, INVALID_REQUEST);
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiError> handleMethodNotSupported(HttpRequestMethodNotSupportedException ex) {
        return respond(ErrorCode.INVALID_PARAMETER, METHOD_NOT_SUPPORTED);
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<ApiError> handleUnsupportedMediaType(HttpMediaTypeNotSupportedException ex) {
        return respond(ErrorCode.UNSUPPORTED_MEDIA_TYPE, UNSUPPORTED_MEDIA_TYPE);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiError> handleAccessDenied(AccessDeniedException ex) {
        return respond(ErrorCode.ACCESS_DENIED, SecurityMessages.ACCESS_DENIED);
    }

    @ExceptionHandler(ObjectOptimisticLockingFailureException.class)
    public ResponseEntity<ApiError> handleOptimisticLocking(ObjectOptimisticLockingFailureException ex) {
        return respond(ErrorCode.CONCURRENT_MODIFICATION, CONCURRENT_MODIFICATION);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ApiError> handleDataIntegrityViolation(DataIntegrityViolationException ex) {
        // The exception text holds the conflicting values, so only the fact is logged.
        log.warn("Database integrity constraint violation");
        return respond(ErrorCode.RESOURCE_ALREADY_EXISTS, CONFLICTS_WITH_EXISTING_DATA);
    }

    @ExceptionHandler({NoResourceFoundException.class, NoHandlerFoundException.class})
    public ResponseEntity<ApiError> handleNotFound(Exception ex) {
        return respond(ErrorCode.RESOURCE_NOT_FOUND, NOT_FOUND);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleUnexpected(Exception ex) {
        if (isSpringClientError(ex)) {
            return respond(ErrorCode.MALFORMED_REQUEST, INVALID_REQUEST);
        }
        log.error("Unexpected exception", ex);
        return respond(ErrorCode.INTERNAL_ERROR, UNEXPECTED_ERROR);
    }

    private ResponseEntity<ApiError> respond(ErrorCode errorCode, String message) {
        return respond(errorCode, message, null);
    }

    private ResponseEntity<ApiError> respond(ErrorCode errorCode, String message, Map<String, String> fieldErrors) {
        return ResponseEntity.status(errorCode.getStatus())
                .body(apiErrorFactory.create(errorCode, message, fieldErrors));
    }

    private static void logAppException(AppException ex) {
        if (ex.getErrorCode().getStatus().is5xxServerError()) {
            log.error("System exception code={}", ex.getErrorCode(), ex);
        } else {
            log.warn("Application exception code={} message={}", ex.getErrorCode(), ex.getMessage());
        }
    }

    /** Other Spring MVC client errors (missing header, not acceptable...) stay 4xx instead of becoming a 500. */
    private static boolean isSpringClientError(Exception ex) {
        return ex instanceof ErrorResponse errorResponse && errorResponse.getStatusCode().is4xxClientError();
    }

    private static Stream<ParameterFailure> parameterFailures(ParameterValidationResult parameterValidationResult) {
        String parameter = Objects.requireNonNullElse(
                parameterValidationResult.getMethodParameter().getParameterName(), UNNAMED_PARAMETER);
        return parameterValidationResult.getResolvableErrors().stream()
                .map(error -> new ParameterFailure(parameter, error.getDefaultMessage()));
    }

    private record ParameterFailure(String parameter, String message) {}
}
