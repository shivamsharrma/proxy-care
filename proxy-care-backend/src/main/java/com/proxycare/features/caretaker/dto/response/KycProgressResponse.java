package com.proxycare.features.caretaker.dto.response;

import com.proxycare.features.caretaker.enums.BankVerificationFailureReason;
import com.proxycare.features.caretaker.enums.BankVerificationStatus;
import com.proxycare.features.caretaker.enums.CaretakerStatus;
import com.proxycare.features.caretaker.enums.OnboardingStatus;
import com.proxycare.features.caretaker.enums.VideoVerificationStatus;
import java.time.Instant;
import java.util.List;

/** The KYC checklist and the statuses the Caretaker app routes on; bankFailureReason is set only when bank FAILED. */
public record KycProgressResponse(
        CaretakerStatus status,
        OnboardingStatus onboardingStatus,
        VideoVerificationStatus videoVerificationStatus,
        BankVerificationStatus bankVerificationStatus,
        BankVerificationFailureReason bankFailureReason,
        int stepNumber,
        int totalSteps,
        List<KycStepResponse> steps,
        String rejectedReason,
        Instant vkycSlotAt
) {}
