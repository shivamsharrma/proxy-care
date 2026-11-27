package com.proxycare.common.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/** The error contract with the apps: they switch on these names. Never rename or reuse one. */
@Getter
@RequiredArgsConstructor
public enum ErrorCode {

    // Input errors
    VALIDATION_FAILED(HttpStatus.BAD_REQUEST),
    MALFORMED_REQUEST(HttpStatus.BAD_REQUEST),
    INVALID_PARAMETER(HttpStatus.BAD_REQUEST),
    UNSUPPORTED_MEDIA_TYPE(HttpStatus.UNSUPPORTED_MEDIA_TYPE),
    PAYLOAD_TOO_LARGE(HttpStatus.CONTENT_TOO_LARGE),

    // Authentication and authorization
    UNAUTHENTICATED(HttpStatus.UNAUTHORIZED),
    ACCESS_DENIED(HttpStatus.FORBIDDEN),

    // Business errors
    RESOURCE_NOT_FOUND(HttpStatus.NOT_FOUND),
    RESOURCE_ALREADY_EXISTS(HttpStatus.CONFLICT),
    BUSINESS_RULE_VIOLATION(HttpStatus.UNPROCESSABLE_CONTENT),
    CONCURRENT_MODIFICATION(HttpStatus.CONFLICT),

    // Profile
    PROFILE_NOT_FOUND(HttpStatus.NOT_FOUND),

    // User profile
    APP_USER_NOT_FOUND(HttpStatus.NOT_FOUND),
    APP_USER_ALREADY_EXISTS(HttpStatus.CONFLICT),
    PATIENT_NOT_FOUND(HttpStatus.NOT_FOUND),

    // Caretaker
    CARETAKER_NOT_FOUND(HttpStatus.NOT_FOUND),

    // External service errors
    EXTERNAL_SERVICE_ERROR(HttpStatus.BAD_GATEWAY),
    EXTERNAL_SERVICE_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE),

    // System errors
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR);

    private final HttpStatus status;

}
