package com.proxycare.infrastructure.payout.model;

/**
 * What the bank verifier knows about one test deposit. {@code accountStatus}, {@code registeredName} and
 * {@code nameMatchScore} only mean something once {@code validationStatus} is COMPLETED, and each may be missing.
 * {@code contactId} and {@code fundAccountId} may be null when the vendor's answer doesn't carry them.
 */
public record BankVerification(
        String contactId,
        String fundAccountId,
        String validationId,
        ValidationStatus validationStatus,
        AccountStatus accountStatus,
        String registeredName,
        Double nameMatchScore
) {

    // The registered name is personal data, so it never reaches a log line through toString.
    @Override
    public String toString() {
        return "BankVerification[validationId=" + validationId + ", validationStatus=" + validationStatus
                + ", accountStatus=" + accountStatus + "]";
    }
}
