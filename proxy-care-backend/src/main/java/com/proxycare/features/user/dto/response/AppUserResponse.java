package com.proxycare.features.user.dto.response;

import com.proxycare.common.model.Sex;
import java.util.List;

/** The user profile with their live patients, in the order they were added. The phone is on the profile. */
public record AppUserResponse(
        String fullName,
        Sex sex,
        Integer age,
        String address,
        List<PatientResponse> patients
) {}
