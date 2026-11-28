package com.proxycare.infrastructure.bank.razorpay.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/** {@code GET https://ifsc.razorpay.com/{IFSC}}; the directory's keys are upper case. */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RazorpayIfscResponse(
        @JsonProperty("IFSC") String ifsc,
        @JsonProperty("BANK") String bank,
        @JsonProperty("BRANCH") String branch
) {}
