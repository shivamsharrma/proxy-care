package com.proxycare.features.caretaker.exception;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;

/** An admin decision needs a submitted checklist whose video KYC is still pending. */
public class KycNotSubmittedException extends BusinessException {

    private static final String MESSAGE = "The caretaker's KYC is not waiting for a decision.";

    public KycNotSubmittedException() {
        super(ErrorCode.KYC_NOT_SUBMITTED, MESSAGE);
    }
}
