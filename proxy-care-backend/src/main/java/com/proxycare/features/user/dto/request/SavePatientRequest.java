package com.proxycare.features.user.dto.request;

import com.proxycare.common.model.MobileNumber;
import com.proxycare.common.model.Sex;
import com.proxycare.common.validation.PersonName;
import com.proxycare.features.user.enums.MobilityCategory;
import com.proxycare.features.user.enums.Relation;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.UUID;

/**
 * One family member in the user profile's patients list (Screen 05). {@code id} is null for a new patient and the
 * patient's id for an edit. The owner comes from the token, never from here.
 */
public record SavePatientRequest(
        UUID id,
        @NotNull Relation relation,
        @NotNull
        @Size(min = 2, max = 80)
        @Pattern(regexp = PersonName.FULL_NAME_PATTERN, message = PersonName.FULL_NAME_MESSAGE)
        String fullName,
        @NotNull @Min(0) @Max(120) Integer age,
        @NotNull Sex sex,
        @Valid MobileNumber mobile,
        @NotBlank @Size(max = 300) String address,
        @NotNull MobilityCategory mobilityCategory,
        @Size(max = 500) String healthNotes
) {

    // Trimmed here so the constraints check the text exactly as it will be stored. Blank health notes are none.
    public SavePatientRequest {
        fullName = fullName == null ? null : fullName.trim();
        address = address == null ? null : address.trim();
        healthNotes = healthNotes == null || healthNotes.isBlank() ? null : healthNotes.trim();
    }
}
