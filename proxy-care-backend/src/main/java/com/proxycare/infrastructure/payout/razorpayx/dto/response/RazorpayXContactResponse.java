package com.proxycare.infrastructure.payout.razorpayx.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/** {@code POST /v1/contacts}: only the id is used. */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RazorpayXContactResponse(String id) {}
