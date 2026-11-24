package com.proxycare.features.patient.dto.request;

import com.proxycare.common.model.MobileNumber;
import com.proxycare.common.model.Sex;
import com.proxycare.common.validation.PersonName;
import com.proxycare.features.patient.enums.MobilityCategory;
import com.proxycare.features.patient.enums.Relation;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** The add family member form (Screen 05). The owner comes from the token, never from here. */
@OwnAddressRequired
public record SavePatientRequest(
        @NotNull Relation relation,
        @NotNull
        @Size(min = 2, max = 80)
        @Pattern(regexp = PersonName.FULL_NAME_PATTERN, message = PersonName.FULL_NAME_MESSAGE)
        String fullName,
        @NotNull @Min(0) @Max(120) Integer age,
        @NotNull Sex sex,
        @Valid MobileNumber mobile,
        @NotNull Boolean livesAtUserAddress,
        String address,
        @NotNull MobilityCategory mobility,
        @Size(max = 500) String healthNotes
) {

    public static final int MAX_ADDRESS_LENGTH = 300;

    // Trimmed here so the constraints check the text exactly as it will be stored. Blank health notes are none.
    public SavePatientRequest {
        fullName = fullName == null ? null : fullName.trim();
        address = address == null ? null : address.trim();
        healthNotes = healthNotes == null || healthNotes.isBlank() ? null : healthNotes.trim();
    }
}
