package com.proxycare.features.caretaker.service;

import com.proxycare.features.caretaker.dto.request.SavePayoutAccountRequest;
import com.proxycare.features.caretaker.dto.response.PayoutAccountResponse;

/**
 * The caller's payout account (C5) and its penny-drop attempts. The Rs 1 test deposit is never sent from a request:
 * BankVerificationJob sends it later. Both methods answer CARETAKER_NOT_FOUND when the caller has no caretakers row.
 */
public interface ICaretakerPayoutService {

    /**
     * C5 Submit for review: resolves the bank and branch from the IFSC on the server, stores a new PENDING attempt
     * (earlier attempts stay as history) and sets the bank verification PENDING. The first submit, at step 4 with
     * onboarding IN_PROGRESS, also sets onboarding SUBMITTED; afterwards a resubmit is allowed only while the bank
     * verification is FAILED. KYC_STEP_LOCKED otherwise (step below 4, bank PENDING or VERIFIED, onboarding
     * COMPLETED); IFSC_NOT_FOUND; EXTERNAL_SERVICE_UNAVAILABLE or EXTERNAL_SERVICE_ERROR when the IFSC lookup fails.
     */
    PayoutAccountResponse saveCurrentPayoutAccount(SavePayoutAccountRequest savePayoutAccountRequest);

    /** The caller's latest attempt; PAYOUT_ACCOUNT_NOT_FOUND before the first submit. */
    PayoutAccountResponse getCurrentPayoutAccount();
}
