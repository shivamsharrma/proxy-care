package com.proxycare.features.caretaker.enums;

/** Why a penny-drop attempt FAILED; the caretaker can resubmit the payout account after any of them. */
public enum BankVerificationFailureReason {
    DEPOSIT_FAILED,
    NAME_MISMATCH,
    NAME_VERIFICATION_UNAVAILABLE
}
