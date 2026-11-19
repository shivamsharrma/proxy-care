package com.proxycare.common.error;

/**
 * The only custom exception. {@code detail} is returned to the client as a safe English fallback, so
 * it must never contain personal data.
 */
public class AppException extends RuntimeException {

    private final ErrorCode code;

    public AppException(ErrorCode code, String detail) {
        super(detail);
        this.code = code;
    }

    public ErrorCode code() {
        return code;
    }

    public String detail() {
        return getMessage();
    }
}
