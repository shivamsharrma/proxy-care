package com.proxycare.features.profile.dto.request;

import com.proxycare.common.security.authorization.Role;
import com.proxycare.features.profile.enums.PreferredLanguage;
import jakarta.validation.constraints.NotNull;

/** The calling app's role and the language chosen on Welcome. Id and phone come from the token only. */
public record ProfileUpdateRequest(
        @NotNull Role role,
        @NotNull PreferredLanguage preferredLanguage
) {}
