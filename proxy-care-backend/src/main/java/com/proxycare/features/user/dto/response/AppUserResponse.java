package com.proxycare.features.user.dto.response;

import com.proxycare.common.model.Sex;

public record AppUserResponse(
        String fullName,
        Sex sex,
        Integer age,
        String address,
        String phone
) {}
