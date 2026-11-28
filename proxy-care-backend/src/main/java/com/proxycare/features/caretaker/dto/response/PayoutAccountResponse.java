package com.proxycare.features.caretaker.dto.response;

import com.proxycare.features.caretaker.enums.BankVerificationFailureReason;
import com.proxycare.features.caretaker.enums.BankVerificationStatus;

/** The caretaker's latest payout account attempt. Only the last 4 digits of the account number ever leave. */
public record PayoutAccountResponse(
        BankVerificationStatus status,
        BankVerificationFailureReason failureReason,
        String accountHolderName,
        String accountLast4,
        String ifsc,
        String bankName,
        String branch
) {}
