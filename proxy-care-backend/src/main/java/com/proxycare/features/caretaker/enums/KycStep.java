package com.proxycare.features.caretaker.enums;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * The KYC checklist steps in order. {@code stepNumber} is what caretakers.kyc_step stores, so it is fixed per step
 * and never derived from the declaration order.
 */
@Getter
@RequiredArgsConstructor
public enum KycStep {
    MOBILE_NUMBER(1),
    BASIC_INFORMATION(2),
    PHOTO_AND_VIDEO_KYC(3),
    PAYOUT_ACCOUNT(4);

    private final int stepNumber;
}
