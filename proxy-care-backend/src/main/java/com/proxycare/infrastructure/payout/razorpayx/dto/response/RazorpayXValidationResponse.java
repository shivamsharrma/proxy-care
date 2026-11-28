package com.proxycare.infrastructure.payout.razorpayx.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * A fund account validation ({@code fav_...}); {@code status} is created, completed or failed. {@code notes} is an
 * object, or an empty array when the validation has none, so it is read as whatever JSON it is.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RazorpayXValidationResponse(
        String id,
        String status,
        RazorpayXValidationResults results,
        @JsonProperty("fund_account") RazorpayXFundAccountResponse fundAccount,
        Object notes
) {}
