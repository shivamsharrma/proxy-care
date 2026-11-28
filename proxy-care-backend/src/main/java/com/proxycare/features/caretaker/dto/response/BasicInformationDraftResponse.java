package com.proxycare.features.caretaker.dto.response;

import com.proxycare.common.model.MobileNumber;
import com.proxycare.common.model.Sex;
import com.proxycare.features.caretaker.enums.MaritalStatus;

/** The C2 form as last submitted and rejected, to restore it; every field may be null or invalid. */
public record BasicInformationDraftResponse(
        String fullName,
        Sex sex,
        Integer age,
        String email,
        MobileNumber emergencyContact,
        String residentialAddress,
        String occupation,
        MaritalStatus maritalStatus
) {}
