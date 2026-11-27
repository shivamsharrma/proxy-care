package com.proxycare.support;

import java.util.UUID;

/**
 * A caretakers row as stored, read by {@link TestDb#caretakerOf(UUID)}. The statuses are the enum names
 * (PENDING, IN_PROGRESS, ...); {@code bankVerificationStatus} is null until the payout account is first submitted.
 */
public record CaretakerRow(
        UUID id,
        UUID profileId,
        String status,
        String onboardingStatus,
        String videoVerificationStatus,
        String bankVerificationStatus,
        Integer kycStep,
        String rejectedReason) {}
