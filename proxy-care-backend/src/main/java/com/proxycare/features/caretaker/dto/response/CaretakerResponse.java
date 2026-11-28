package com.proxycare.features.caretaker.dto.response;

import com.proxycare.common.model.MobileNumber;
import com.proxycare.common.model.Sex;
import com.proxycare.features.caretaker.enums.BankVerificationStatus;
import com.proxycare.features.caretaker.enums.CaretakerStatus;
import com.proxycare.features.caretaker.enums.MaritalStatus;
import com.proxycare.features.caretaker.enums.OnboardingStatus;
import com.proxycare.features.caretaker.enums.VideoVerificationStatus;
import java.util.UUID;

/** The caretaker's saved basic information (never draft values) and statuses; C2 fields are null until saved. */
public record CaretakerResponse(
        UUID id,
        String fullName,
        Sex sex,
        Integer age,
        String email,
        MobileNumber emergencyContact,
        String residentialAddress,
        String occupation,
        MaritalStatus maritalStatus,
        CaretakerStatus status,
        OnboardingStatus onboardingStatus,
        VideoVerificationStatus videoVerificationStatus,
        BankVerificationStatus bankVerificationStatus,
        int kycStep
) {}
