package com.proxycare.features.caretaker.service;

import com.proxycare.features.caretaker.entity.CaretakerEntity;
import com.proxycare.features.caretaker.enums.BankVerificationStatus;
import com.proxycare.features.caretaker.enums.CaretakerStatus;
import com.proxycare.features.caretaker.enums.OnboardingStatus;
import com.proxycare.features.caretaker.enums.VideoVerificationStatus;
import org.springframework.stereotype.Component;

/**
 * The one rule for when a caretaker may start working: video KYC approved and bank account verified, in either
 * order. Called after each of the two outcomes is recorded (admin decision, bank verification).
 */
@Component
public class CaretakerActivation {

    /** Makes the caretaker ACTIVE with onboarding COMPLETED once both checks passed; otherwise changes nothing. */
    public void activateIfReady(CaretakerEntity caretakerEntity) {
        boolean videoApproved = caretakerEntity.getVideoVerificationStatus() == VideoVerificationStatus.APPROVED;
        boolean bankVerified = caretakerEntity.getBankVerificationStatus() == BankVerificationStatus.VERIFIED;
        if (!videoApproved || !bankVerified) {
            return;
        }

        caretakerEntity.setStatus(CaretakerStatus.ACTIVE);
        caretakerEntity.setOnboardingStatus(OnboardingStatus.COMPLETED);
    }
}
