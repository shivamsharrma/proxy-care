package com.proxycare.infrastructure.payout.razorpayx.exception;

import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.exception.SystemException;

/** A RazorpayX call failed; the code says whether it was unreachable or answered with an error. */
public class RazorpayXException extends SystemException {

    private static final String MESSAGE = "Bank account verification failed. Please try again.";

    public RazorpayXException(ErrorCode errorCode, Throwable cause) {
        super(errorCode, MESSAGE, cause);
    }

    public RazorpayXException(ErrorCode errorCode) {
        super(errorCode, MESSAGE);
    }
}
