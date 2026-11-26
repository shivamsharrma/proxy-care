package com.proxycare.features.user.dto.request;

import com.proxycare.common.model.Sex;
import com.proxycare.common.validation.PersonName;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;

/**
 * The user profile (Screen 04) with the full list of their family members (Screens 05-06). The list replaces the
 * stored one: see {@code IAppUserService}. Owner and phone come from the token and profile, never from here.
 */
public record SaveAppUserRequest(
        @NotNull
        @Size(min = 2, max = 50)
        @Pattern(regexp = PersonName.FULL_NAME_PATTERN, message = PersonName.FULL_NAME_MESSAGE)
        String fullName,
        @NotNull Sex sex,
        @Min(18) @Max(120) Integer age,
        @NotBlank @Size(max = 300) String address,
        @NotNull @UniquePatientIds List<@NotNull @Valid SavePatientRequest> patients
) {

    // Trimmed here so the constraints above check the name exactly as it will be stored.
    public SaveAppUserRequest {
        fullName = fullName == null ? null : fullName.trim();
    }
}
