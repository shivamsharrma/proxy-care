package com.proxycare.features.caretaker.service;

import com.proxycare.features.caretaker.dto.response.KycProgressResponse;

/** The caller's caretaker onboarding: one caretakers row per CARETAKER profile. */
public interface ICaretakerService {

    /**
     * Creates the caller's caretakers row at the basic-information step (the mobile number is verified by sign-in),
     * PENDING with onboarding IN_PROGRESS and video verification PENDING. Leaves an existing row untouched. Joins the
     * caller's transaction, so the caller's profile row must already be saved in it.
     */
    void ensureCurrentCaretaker();

    /**
     * The caller's KYC checklist: steps before the stored step are DONE, the stored step is CURRENT, later ones TODO.
     * Once onboarding is SUBMITTED or COMPLETED every step is DONE at step 4 of 4. CARETAKER_NOT_FOUND without a row.
     */
    KycProgressResponse getCurrentKycProgress();
}
