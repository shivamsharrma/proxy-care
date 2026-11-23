package com.proxycare.features.user.exception;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;

/** The user has already completed the user profile screen; it is changed with an update instead. */
public class AppUserAlreadyExistsException extends BusinessException {

    private static final String MESSAGE = "User profile already exists. Update it instead.";

    public AppUserAlreadyExistsException() {
        super(ErrorCode.APP_USER_ALREADY_EXISTS, MESSAGE);
    }
}
