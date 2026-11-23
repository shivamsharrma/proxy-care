package com.proxycare.features.user.service;

import com.proxycare.features.user.dto.request.SaveAppUserRequest;
import com.proxycare.features.user.dto.response.AppUserResponse;

public interface IAppUserService {

    /** The caller's user profile with their verified profile phone; APP_USER_NOT_FOUND until it is created. */
    AppUserResponse getCurrentAppUser();

    /** Creates the caller's user profile; APP_USER_ALREADY_EXISTS when they already have one. */
    AppUserResponse createCurrentAppUser(SaveAppUserRequest saveAppUserRequest);

    /** Fully replaces the caller's user profile (an omitted age is cleared); APP_USER_NOT_FOUND until it is created. */
    AppUserResponse updateCurrentAppUser(SaveAppUserRequest saveAppUserRequest);
}
