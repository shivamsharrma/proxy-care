package com.proxycare.infrastructure.bank.razorpay.exception;

import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.exception.SystemException;

/** The IFSC directory failed; the code says whether it was unreachable or answered with an error. */
public class RazorpayIfscException extends SystemException {

    private static final String MESSAGE = "Bank details could not be looked up. Please try again.";

    public RazorpayIfscException(ErrorCode errorCode, Throwable cause) {
        super(errorCode, MESSAGE, cause);
    }
}
