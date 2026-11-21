package com.proxycare.common.exception;

/** We or a vendor failed. Logged with its cause; the client sees only the code and message. */
public class SystemException extends AppException {

    public SystemException(ErrorCode errorCode, String message) {
        super(errorCode, message);
    }

    public SystemException(ErrorCode errorCode, String message, Throwable cause) {
        super(errorCode, message, cause);
    }
}
