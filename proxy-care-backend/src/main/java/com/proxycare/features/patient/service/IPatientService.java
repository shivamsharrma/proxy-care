package com.proxycare.features.patient.service;

import com.proxycare.common.api.PageResponse;
import com.proxycare.features.patient.dto.request.SavePatientRequest;
import com.proxycare.features.patient.dto.response.PatientResponse;
import org.springframework.data.domain.Pageable;

public interface IPatientService {

    /**
     * Adds a patient to the caller's family; each call adds another one. When the patient lives at the user's
     * address, the user's current address is copied and the request's address is ignored (not validated);
     * otherwise the request's own address is required. APP_USER_NOT_FOUND until the user profile is created.
     */
    PatientResponse createPatientForCurrentUser(SavePatientRequest savePatientRequest);

    /**
     * The caller's patients, oldest first; only the page number and size of {@code pageable} are used.
     * APP_USER_NOT_FOUND until the user profile is created.
     */
    PageResponse<PatientResponse> getCurrentUserPatients(Pageable pageable);
}
