package com.proxycare.features.profile.exception;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;

/** Signed in with Supabase but not onboarded yet: the app shows onboarding. */
public class ProfileNotFoundException extends BusinessException {

    private static final String MESSAGE = "Profile not found. Complete onboarding first.";

    public ProfileNotFoundException() {
        super(ErrorCode.PROFILE_NOT_FOUND, MESSAGE);
    }
}
