package com.proxycare.common.exception;

/** A business rule said no: not found, already exists, not allowed in this state. */
public class BusinessException extends AppException {

    public BusinessException(ErrorCode errorCode, String message) {
        super(errorCode, message);
    }
}
