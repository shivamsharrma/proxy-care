package com.proxycare.features.caretaker.service;

import com.proxycare.features.caretaker.dto.request.SaveBasicInformationRequest;
import com.proxycare.features.caretaker.dto.request.SaveIdentityCheckRequest;
import com.proxycare.features.caretaker.dto.request.VkycBookingRequest;
import com.proxycare.features.caretaker.dto.response.BasicInformationDraftResponse;
import com.proxycare.features.caretaker.dto.response.CaretakerResponse;
import com.proxycare.features.caretaker.dto.response.KycProgressResponse;

/**
 * The caller's caretaker onboarding: one caretakers row per CARETAKER profile. Every method except
 * {@link #ensureCurrentCaretaker()} answers CARETAKER_NOT_FOUND when the caller has no row.
 */
public interface ICaretakerService {

    /**
     * Creates the caller's caretakers row at the basic-information step (the mobile number is verified by sign-in),
     * PENDING with onboarding IN_PROGRESS and video verification PENDING. Leaves an existing row untouched. Joins the
     * caller's transaction, so the caller's profile row must already be saved in it.
     */
    void ensureCurrentCaretaker();

    /**
     * The caller's KYC checklist: steps before the stored step are DONE, the stored step is CURRENT, later ones TODO.
     * Once onboarding is SUBMITTED or COMPLETED every step is DONE at step 4 of 4. bankFailureReason is the latest
     * attempt's reason while the bank verification is FAILED, else null.
     */
    KycProgressResponse getCurrentKycProgress();

    /** The caller's saved basic information and statuses; never draft values. */
    CaretakerResponse getCurrentCaretaker();

    /**
     * C2 Save and continue (decision OQ-2). Stores the request as the draft first, and keeps it even when the save
     * is rejected: 400 VALIDATION_FAILED with fieldErrors, or EMAIL_ALREADY_IN_USE when another caretaker has the
     * email. A valid request becomes the saved basic information, the draft is deleted and the step moves from 2 to
     * 3 (never backwards). KYC_STEP_LOCKED, with nothing stored, once onboarding is no longer IN_PROGRESS.
     */
    KycProgressResponse saveCurrentBasicInformation(SaveBasicInformationRequest saveBasicInformationRequest);

    /** The last rejected C2 form, to restore it; BASIC_INFORMATION_DRAFT_NOT_FOUND when there is none. */
    BasicInformationDraftResponse getCurrentBasicInformationDraft();

    /**
     * C4 Book call: records (or replaces) the caller's photo file and the video KYC call time, and moves the step
     * from 3 to 4. PHOTO_PATH_NOT_OWNED when the path is outside {@code <caller id>/}; VALIDATION_FAILED on
     * {@code vkycSlotAt} unless it is in the future; KYC_STEP_LOCKED unless the step is at least 3 and onboarding is
     * IN_PROGRESS.
     */
    KycProgressResponse saveCurrentIdentityCheck(SaveIdentityCheckRequest saveIdentityCheckRequest);

    /**
     * C6 Reschedule call: overwrites the video KYC call time. VALIDATION_FAILED on {@code vkycSlotAt} unless it is
     * in the future; KYC_STEP_LOCKED unless onboarding is SUBMITTED and video verification still PENDING.
     */
    KycProgressResponse rebookCurrentVkycCall(VkycBookingRequest vkycBookingRequest);
}
