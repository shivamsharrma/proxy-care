package com.proxycare.features.caretaker.exception;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;

/** The KYC step can't be changed now: an earlier step isn't done, or the checklist has been submitted. */
public class KycStepLockedException extends BusinessException {

    private static final String MESSAGE = "This KYC step can't be changed now.";

    public KycStepLockedException() {
        super(ErrorCode.KYC_STEP_LOCKED, MESSAGE);
    }
}
