package com.proxycare.features.caretaker.dto.response;

import com.proxycare.features.caretaker.enums.BankVerificationStatus;
import com.proxycare.features.caretaker.enums.CaretakerStatus;
import com.proxycare.features.caretaker.enums.OnboardingStatus;
import com.proxycare.features.caretaker.enums.VideoVerificationStatus;
import java.util.List;

/** The KYC checklist and the statuses the Caretaker app routes on. */
public record KycProgressResponse(
        CaretakerStatus status,
        OnboardingStatus onboardingStatus,
        VideoVerificationStatus videoVerificationStatus,
        BankVerificationStatus bankVerificationStatus,
        int stepNumber,
        int totalSteps,
        List<KycStepResponse> steps,
        String rejectedReason
) {}
