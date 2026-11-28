package com.proxycare.features.caretaker.exception;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;

/** The caretaker hasn't submitted a payout account yet. */
public class PayoutAccountNotFoundException extends BusinessException {

    private static final String MESSAGE = "No payout account has been added yet.";

    public PayoutAccountNotFoundException() {
        super(ErrorCode.PAYOUT_ACCOUNT_NOT_FOUND, MESSAGE);
    }
}
