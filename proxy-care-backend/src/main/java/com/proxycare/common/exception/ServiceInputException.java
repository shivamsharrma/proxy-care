package com.proxycare.common.exception;

/** The caller sent input a service cannot accept, beyond what Bean Validation checks. */
public class ServiceInputException extends AppException {

    public ServiceInputException(ErrorCode errorCode, String message) {
        super(errorCode, message);
    }
}
