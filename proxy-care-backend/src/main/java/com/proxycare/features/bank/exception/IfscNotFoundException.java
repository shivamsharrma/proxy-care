package com.proxycare.features.bank.exception;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;

/** The IFSC is well formed but no bank branch has it. */
public class IfscNotFoundException extends BusinessException {

    private static final String MESSAGE = "We couldn't find this IFSC.";

    public IfscNotFoundException() {
        super(ErrorCode.IFSC_NOT_FOUND, MESSAGE);
    }
}
