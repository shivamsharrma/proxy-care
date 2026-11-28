package com.proxycare.features.caretaker.dto.request;

import com.proxycare.common.model.MobileNumber;
import com.proxycare.common.model.Sex;
import com.proxycare.common.validation.PersonName;
import com.proxycare.features.caretaker.enums.MaritalStatus;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.Locale;

/**
 * C2 Basic information. Not validated by the controller: the service stores it as the draft first and then checks
 * these constraints (decision OQ-2). Owner and own mobile come from the token, never from here.
 */
public record SaveBasicInformationRequest(
        @NotNull
        @Size(min = 2, max = 80)
        @Pattern(regexp = PersonName.FULL_NAME_PATTERN, message = PersonName.FULL_NAME_MESSAGE)
        String fullName,
        @NotNull Sex sex,
        @NotNull @Min(18) @Max(70) Integer age,
        @NotNull
        @Size(max = 254)
        @Pattern(regexp = SaveBasicInformationRequest.EMAIL_PATTERN, message = SaveBasicInformationRequest.EMAIL_MESSAGE)
        String email,
        @NotNull @Valid MobileNumber emergencyContact,
        @NotBlank @Size(max = 300) String residentialAddress,
        @Size(max = 100) String occupation,
        MaritalStatus maritalStatus
) {

    // A dotted domain is required, so "anita@example" fails (Bean Validation's @Email accepts it).
    static final String EMAIL_PATTERN = "[a-z0-9._%+-]+@[a-z0-9-]+(\\.[a-z0-9-]+)*\\.[a-z]{2,}";
    static final String EMAIL_MESSAGE = "must be a valid email address";

    // Trimmed (and the email lower-cased) here, so the draft and the constraints see the text as it will be stored.
    // A blank occupation is none.
    public SaveBasicInformationRequest {
        fullName = fullName == null ? null : fullName.trim();
        email = email == null ? null : email.trim().toLowerCase(Locale.ROOT);
        residentialAddress = residentialAddress == null ? null : residentialAddress.trim();
        occupation = occupation == null || occupation.isBlank() ? null : occupation.trim();
    }
}
