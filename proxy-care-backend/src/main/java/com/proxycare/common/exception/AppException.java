package com.proxycare.common.exception;

import lombok.Getter;

/**
 * Base of every exception we throw on purpose. The {@link ErrorCode} decides the HTTP status; the message is
 * returned to the client, so it must never hold personal data.
 */
@Getter
public abstract class AppException extends RuntimeException {

    private final ErrorCode errorCode;

    protected AppException(ErrorCode errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }

    protected AppException(ErrorCode errorCode, String message, Throwable cause) {
        super(message, cause);
        this.errorCode = errorCode;
    }
}
