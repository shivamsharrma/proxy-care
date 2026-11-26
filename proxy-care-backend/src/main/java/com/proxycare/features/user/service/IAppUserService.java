package com.proxycare.features.user.service;

import com.proxycare.features.user.dto.request.SaveAppUserRequest;
import com.proxycare.features.user.dto.response.AppUserResponse;

/**
 * The caller's user profile and their family (patients). Both saves sync the request's patients list to the stored
 * one: an entry with an id replaces that live patient (PATIENT_NOT_FOUND when it is not one of the caller's live
 * patients), an entry without an id adds a patient, and a live patient left out of the list is soft-deleted.
 */
public interface IAppUserService {

    /** The caller's user profile and live patients; APP_USER_NOT_FOUND until it is created. */
    AppUserResponse getCurrentAppUser();

    /** Creates the caller's user profile and patients; APP_USER_ALREADY_EXISTS when they already have one. */
    AppUserResponse createCurrentAppUser(SaveAppUserRequest saveAppUserRequest);

    /**
     * Fully replaces the caller's user profile and patients (an omitted age or optional patient field is cleared);
     * APP_USER_NOT_FOUND until it is created.
     */
    AppUserResponse updateCurrentAppUser(SaveAppUserRequest saveAppUserRequest);
}
