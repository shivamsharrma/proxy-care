package com.proxycare.infrastructure.payout.razorpayx.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/** A validation's {@code results}: {@code account_status} is active, invalid or null; each field may be missing. */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RazorpayXValidationResults(
        @JsonProperty("account_status") String accountStatus,
        @JsonProperty("registered_name") String registeredName,
        @JsonProperty("name_match_score") Double nameMatchScore
) {

    @Override
    public String toString() {
        return "RazorpayXValidationResults[accountStatus=" + accountStatus + "]";
    }
}
