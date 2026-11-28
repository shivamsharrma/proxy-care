package com.proxycare.infrastructure.payout.exception;

import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.exception.ServiceInputException;

/** A webhook's signature is missing or doesn't match its raw body, so the delivery is not trusted. */
public class WebhookSignatureInvalidException extends ServiceInputException {

    private static final String MESSAGE = "The webhook signature is invalid.";

    public WebhookSignatureInvalidException() {
        super(ErrorCode.WEBHOOK_SIGNATURE_INVALID, MESSAGE);
    }
}
