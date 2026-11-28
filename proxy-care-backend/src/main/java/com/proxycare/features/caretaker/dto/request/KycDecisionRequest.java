package com.proxycare.features.caretaker.dto.request;

import com.proxycare.features.caretaker.enums.KycDecision;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** An admin's video KYC decision. The reason is required when rejecting (checked by the service). */
public record KycDecisionRequest(
        @NotNull KycDecision decision,
        @Size(max = 500) String reason
) {

    // A blank reason is none.
    public KycDecisionRequest {
        reason = reason == null || reason.isBlank() ? null : reason.trim();
    }
}
