package com.proxycare.features.patient.dto.response;

import com.proxycare.common.model.MobileNumber;
import com.proxycare.common.model.Sex;
import com.proxycare.features.patient.enums.MobilityCategory;
import com.proxycare.features.patient.enums.Relation;
import java.util.UUID;

public record PatientResponse(
        UUID id,
        Relation relation,
        String fullName,
        Integer age,
        Sex sex,
        MobileNumber mobile,
        boolean livesAtUserAddress,
        String address,
        MobilityCategory mobility,
        String healthNotes
) {}
