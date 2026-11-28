package com.proxycare.features.caretaker.dto.request;

import jakarta.validation.constraints.NotNull;
import java.time.Instant;

/** C6 Reschedule call: the new video KYC call time (any future instant, OQ-5). */
public record VkycBookingRequest(@NotNull Instant vkycSlotAt) {}
