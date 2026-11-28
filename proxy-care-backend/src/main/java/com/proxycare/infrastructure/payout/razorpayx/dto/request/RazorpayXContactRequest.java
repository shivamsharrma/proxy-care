package com.proxycare.infrastructure.payout.razorpayx.dto.request;

import com.fasterxml.jackson.annotation.JsonProperty;

/** {@code POST /v1/contacts}. RazorpayX returns the existing contact for the same name and reference id. */
public record RazorpayXContactRequest(
        String name,
        @JsonProperty("reference_id") String referenceId
) {}
