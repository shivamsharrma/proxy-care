package com.proxycare.features.user.exception;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;

/** A patients list entry names an id that is not one of the caller's live patients. */
public class PatientNotFoundException extends BusinessException {

    private static final String MESSAGE = "Family member not found. Reload your family and try again.";

    public PatientNotFoundException() {
        super(ErrorCode.PATIENT_NOT_FOUND, MESSAGE);
    }
}
