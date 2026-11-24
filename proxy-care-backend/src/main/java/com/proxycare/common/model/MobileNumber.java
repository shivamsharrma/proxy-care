package com.proxycare.common.model;

import jakarta.persistence.Embeddable;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

/**
 * A mobile number typed into a form, sent in JSON as {@code {countryCode, number}} and embedded in an entity as
 * two columns. Each entity names its columns with {@code @AttributeOverride}s ({@code <name>_country_code},
 * {@code <name>_number}). A request field of this type needs {@code @Valid} for these rules to run.
 * "Both parts or none" is enforced only by that validation ({@code @NotNull} on both parts); the database has no
 * check constraint for it (decision OQ-22).
 */
@Embeddable
public record MobileNumber(
        @NotNull @Pattern(regexp = MobileNumber.INDIA_COUNTRY_CODE_PATTERN, message = MobileNumber.COUNTRY_CODE_MESSAGE)
        String countryCode,
        @NotNull @Pattern(regexp = MobileNumber.INDIA_NUMBER_PATTERN, message = MobileNumber.NUMBER_MESSAGE)
        String number
) {

    // MVP: India only.
    static final String INDIA_COUNTRY_CODE_PATTERN = "\\+91";
    static final String INDIA_NUMBER_PATTERN = "[6-9][0-9]{9}";
    static final String COUNTRY_CODE_MESSAGE = "must be +91";
    static final String NUMBER_MESSAGE = "must be 10 digits starting with 6, 7, 8 or 9";
}
