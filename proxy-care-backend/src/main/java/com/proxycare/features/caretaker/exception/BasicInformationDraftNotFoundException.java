package com.proxycare.features.caretaker.exception;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;

/** No rejected basic-information save is waiting to be resumed. */
public class BasicInformationDraftNotFoundException extends BusinessException {

    private static final String MESSAGE = "No basic information draft found.";

    public BasicInformationDraftNotFoundException() {
        super(ErrorCode.BASIC_INFORMATION_DRAFT_NOT_FOUND, MESSAGE);
    }
}
