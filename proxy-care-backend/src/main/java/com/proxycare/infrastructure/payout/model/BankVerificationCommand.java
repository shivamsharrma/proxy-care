package com.proxycare.infrastructure.payout.model;

import java.util.UUID;

/**
 * Ask the bank verifier to send the Rs 1 test deposit for one attempt. {@code verificationRequestId} identifies the
 * attempt at the vendor, so a retry can find it instead of sending a second deposit.
 */
public record BankVerificationCommand(
        UUID verificationRequestId,
        UUID caretakerId,
        String accountHolderName,
        String accountNumber,
        String ifsc
) {

    // The holder name and account number are personal data, so they never reach a log line through toString.
    @Override
    public String toString() {
        return "BankVerificationCommand[verificationRequestId=" + verificationRequestId
                + ", caretakerId=" + caretakerId + "]";
    }
}
