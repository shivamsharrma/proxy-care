package com.proxycare.features.caretaker.service;

import com.proxycare.features.caretaker.dto.request.KycDecisionRequest;
import com.proxycare.features.caretaker.dto.response.CaretakerResponse;
import java.util.UUID;

/** What an admin does to any caretaker; the caller's ADMIN role is checked by the controller. */
public interface IAdminCaretakerService {

    /**
     * Records the video KYC decision on a submitted caretaker ({@code caretakerId} is caretakers.id), with the
     * reason kept only when REJECTED, then activates the caretaker if the bank account is already verified.
     * VALIDATION_FAILED on {@code reason} when rejecting without one; CARETAKER_NOT_FOUND; KYC_NOT_SUBMITTED unless
     * onboarding is SUBMITTED and video verification still PENDING.
     */
    CaretakerResponse decideKyc(UUID caretakerId, KycDecisionRequest kycDecisionRequest);
}
