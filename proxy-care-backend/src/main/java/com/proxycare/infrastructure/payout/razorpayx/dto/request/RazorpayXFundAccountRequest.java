package com.proxycare.infrastructure.payout.razorpayx.dto.request;

import com.fasterxml.jackson.annotation.JsonProperty;

/** {@code POST /v1/fund_accounts}. RazorpayX returns the existing one for the same contact and bank account. */
public record RazorpayXFundAccountRequest(
        @JsonProperty("contact_id") String contactId,
        @JsonProperty("account_type") String accountType,
        @JsonProperty("bank_account") RazorpayXBankAccountRequest bankAccount
) {}
