package com.proxycare.features.caretaker.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;

/** C4 Photo & identity check: the uploaded photo and the video KYC call time (any future instant, OQ-5). */
public record SaveIdentityCheckRequest(
        @NotNull @Valid PhotoFileRequest photo,
        @NotNull Instant vkycSlotAt
) {}
