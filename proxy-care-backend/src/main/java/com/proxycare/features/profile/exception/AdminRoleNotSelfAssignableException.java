package com.proxycare.features.profile.exception;

import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.exception.ServiceInputException;

/** An app asked to give its own user the ADMIN role; admins are never self-assigned. */
public class AdminRoleNotSelfAssignableException extends ServiceInputException {

    private static final String MESSAGE = "The ADMIN role cannot be self-assigned";

    public AdminRoleNotSelfAssignableException() {
        super(ErrorCode.VALIDATION_FAILED, MESSAGE);
    }
}
