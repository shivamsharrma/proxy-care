package com.proxycare.infrastructure.payout.razorpayx.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/** A fund account, from {@code POST /v1/fund_accounts} or inside a validation: only the ids are used. */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RazorpayXFundAccountResponse(
        String id,
        @JsonProperty("contact_id") String contactId
) {}
