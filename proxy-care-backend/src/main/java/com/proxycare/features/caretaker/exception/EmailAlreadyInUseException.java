package com.proxycare.features.caretaker.exception;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;

/** Another caretaker already saved this email. The email itself is never part of the message. */
public class EmailAlreadyInUseException extends BusinessException {

    private static final String MESSAGE = "This email is already in use.";

    public EmailAlreadyInUseException() {
        super(ErrorCode.EMAIL_ALREADY_IN_USE, MESSAGE);
    }
}
