package com.proxycare.features.user.dto.request;

import com.proxycare.common.model.Sex;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** The user profile form (Screen 04). Owner and phone come from the token and profile, never from here. */
public record SaveAppUserRequest(
        @NotNull
        @Size(min = 2, max = 50)
        @Pattern(regexp = SaveAppUserRequest.FULL_NAME_PATTERN, message = SaveAppUserRequest.FULL_NAME_MESSAGE)
        String fullName,
        @NotNull Sex sex,
        @Min(18) @Max(120) Integer age,
        @NotBlank @Size(max = 300) String address
) {

    private static final String LATIN_LETTERS = "A-Za-z";
    private static final String NAME_PUNCTUATION = " .'-";
    private static final String DEVANAGARI_LETTERS = "\\u0904-\\u0939\\u0958-\\u0961\\u0972-\\u097F";
    private static final String DEVANAGARI_MARKS = "\\u0901-\\u0903\\u093C\\u093E-\\u094C\\u094D\\u0962-\\u0963";

    // Devanagari marks are combining characters, so each must follow a Devanagari letter or mark. The rest
    // of the block (danda, digits, avagraha, Om, Vedic accents) stays out. The lookahead needs one letter.
    static final String FULL_NAME_PATTERN =
            "(?=.*[" + LATIN_LETTERS + DEVANAGARI_LETTERS + "])"
                    + "(?:[" + LATIN_LETTERS + NAME_PUNCTUATION + "]"
                    + "|[" + DEVANAGARI_LETTERS + "][" + DEVANAGARI_MARKS + "]*)*";
    static final String FULL_NAME_MESSAGE = "may contain only English or Hindi letters, spaces and . ' -";

    // Trimmed here so the constraints above check the name exactly as it will be stored.
    public SaveAppUserRequest {
        fullName = fullName == null ? null : fullName.trim();
    }
}
