package com.proxycare.features.caretaker.entity;

import com.proxycare.common.model.MobileNumber;
import com.proxycare.common.model.Sex;
import com.proxycare.features.caretaker.enums.MaritalStatus;

/** The C2 form exactly as last submitted, unvalidated, stored as JSON in caretakers.basic_information_draft. */
public record BasicInformationDraft(
        String fullName,
        Sex sex,
        Integer age,
        String email,
        MobileNumber emergencyContact,
        String residentialAddress,
        String occupation,
        MaritalStatus maritalStatus
) {}
