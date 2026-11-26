package com.proxycare.features.user.dto.response;

import com.proxycare.common.model.MobileNumber;
import com.proxycare.common.model.Sex;
import com.proxycare.features.user.enums.MobilityCategory;
import com.proxycare.features.user.enums.Relation;
import java.util.UUID;

public record PatientResponse(
        UUID id,
        Relation relation,
        String fullName,
        Integer age,
        Sex sex,
        MobileNumber mobile,
        String address,
        MobilityCategory mobilityCategory,
        String healthNotes
) {}
