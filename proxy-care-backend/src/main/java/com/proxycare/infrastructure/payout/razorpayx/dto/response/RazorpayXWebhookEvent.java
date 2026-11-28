package com.proxycare.infrastructure.payout.razorpayx.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.Map;

/**
 * A webhook delivery, e.g. {@code fund_account.validation.completed}. {@code payload} is keyed by entity type with
 * a literal dotted key: the validation is at {@code payload["fund_account.validation"].entity}.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RazorpayXWebhookEvent(String event, Map<String, RazorpayXWebhookPayloadEntry> payload) {}
