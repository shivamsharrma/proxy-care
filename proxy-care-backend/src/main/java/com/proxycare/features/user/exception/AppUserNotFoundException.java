package com.proxycare.features.user.exception;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;

/** The user has a profile but has not completed the user profile screen yet. */
public class AppUserNotFoundException extends BusinessException {

    private static final String MESSAGE = "User profile not found. Complete your profile first.";

    public AppUserNotFoundException() {
        super(ErrorCode.APP_USER_NOT_FOUND, MESSAGE);
    }
}
