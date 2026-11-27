package com.proxycare.features.caretaker.exception;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;

/** The caller has the CARETAKER role but no caretakers row yet; choosing the role again creates it. */
public class CaretakerNotFoundException extends BusinessException {

    private static final String MESSAGE = "Caretaker not found. Choose the caretaker role first.";

    public CaretakerNotFoundException() {
        super(ErrorCode.CARETAKER_NOT_FOUND, MESSAGE);
    }
}
