package com.proxycare.features.user.service;

import com.proxycare.features.user.dto.request.SaveAppUserRequest;
import com.proxycare.features.user.dto.response.AppUserResponse;

public interface IAppUserService {

    /** The caller's user profile with their verified profile phone; APP_USER_NOT_FOUND until it is saved. */
    AppUserResponse getCurrentAppUser();

    /** Creates or fully replaces the caller's user profile; an omitted age is cleared. */
    AppUserResponse saveCurrentAppUser(SaveAppUserRequest saveAppUserRequest);
}
