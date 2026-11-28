package com.proxycare.infrastructure.payout.model;

/** The decision on one test deposit; every value except PENDING is final. */
public enum BankVerificationVerdict {
    PENDING,
    VERIFIED,
    DEPOSIT_FAILED,
    NAME_MISMATCH,
    NAME_VERIFICATION_UNAVAILABLE
}
