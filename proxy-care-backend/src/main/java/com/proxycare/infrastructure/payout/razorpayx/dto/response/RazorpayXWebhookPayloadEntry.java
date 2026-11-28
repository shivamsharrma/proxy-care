package com.proxycare.infrastructure.payout.razorpayx.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/** One {@code payload} entry of a webhook delivery. */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RazorpayXWebhookPayloadEntry(RazorpayXValidationResponse entity) {}
