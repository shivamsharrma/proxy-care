package com.proxycare.features.profile.dto.response;

import com.proxycare.common.security.authorization.Role;
import com.proxycare.features.profile.enums.PreferredLanguage;
import java.util.Set;
import java.util.UUID;

public record ProfileResponse(
    UUID id,
    String phone,
    Set<Role> roles,
    PreferredLanguage preferredLanguage
) {}
