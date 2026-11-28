package com.proxycare.infrastructure.payout.razorpayx.dto.request;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.Map;

/**
 * {@code POST /v1/fund_accounts/validations}: sends {@code amount} paise from our business account
 * ({@code account_number}). There is no idempotency key; {@code notes} carries our attempt id for reconciliation.
 */
public record RazorpayXValidationRequest(
        @JsonProperty("account_number") String accountNumber,
        @JsonProperty("fund_account") RazorpayXFundAccountReference fundAccount,
        long amount,
        String currency,
        Map<String, String> notes
) {

    @Override
    public String toString() {
        return "RazorpayXValidationRequest[fundAccount=" + fundAccount + ", amount=" + amount + "]";
    }
}
