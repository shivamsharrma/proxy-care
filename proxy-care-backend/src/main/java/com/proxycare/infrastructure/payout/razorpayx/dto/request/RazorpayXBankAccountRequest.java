package com.proxycare.infrastructure.payout.razorpayx.dto.request;

import com.fasterxml.jackson.annotation.JsonProperty;

/** The {@code bank_account} of a fund account. */
public record RazorpayXBankAccountRequest(
        String name,
        String ifsc,
        @JsonProperty("account_number") String accountNumber
) {

    @Override
    public String toString() {
        return "RazorpayXBankAccountRequest[ifsc=" + ifsc + "]";
    }
}
