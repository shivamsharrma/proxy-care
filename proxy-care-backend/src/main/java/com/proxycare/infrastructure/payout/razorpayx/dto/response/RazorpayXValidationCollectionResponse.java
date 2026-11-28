package com.proxycare.infrastructure.payout.razorpayx.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;

/** {@code GET /v1/fund_accounts/validations}: one page of validations. */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RazorpayXValidationCollectionResponse(List<RazorpayXValidationResponse> items) {}
