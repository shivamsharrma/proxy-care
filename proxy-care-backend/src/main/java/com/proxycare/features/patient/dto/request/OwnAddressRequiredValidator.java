package com.proxycare.features.patient.dto.request;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

public class OwnAddressRequiredValidator implements ConstraintValidator<OwnAddressRequired, SavePatientRequest> {

    private static final String ADDRESS_FIELD = "address";
    private static final String ADDRESS_TOO_LONG_MESSAGE =
            "must be at most " + SavePatientRequest.MAX_ADDRESS_LENGTH + " characters";

    @Override
    public boolean isValid(SavePatientRequest savePatientRequest, ConstraintValidatorContext constraintValidatorContext) {
        // Only an explicit false needs an own address; a missing flag is reported by its own @NotNull.
        if (!Boolean.FALSE.equals(savePatientRequest.livesAtUserAddress())) {
            return true;
        }

        String address = savePatientRequest.address();
        if (address == null || address.isBlank()) {
            return rejectAddress(
                    constraintValidatorContext, constraintValidatorContext.getDefaultConstraintMessageTemplate());
        }
        if (address.length() > SavePatientRequest.MAX_ADDRESS_LENGTH) {
            return rejectAddress(constraintValidatorContext, ADDRESS_TOO_LONG_MESSAGE);
        }
        return true;
    }

    // Reported on the address field instead of the whole object, so the error is fieldErrors.address.
    private static boolean rejectAddress(ConstraintValidatorContext constraintValidatorContext, String message) {
        constraintValidatorContext.disableDefaultConstraintViolation();
        constraintValidatorContext.buildConstraintViolationWithTemplate(message)
                .addPropertyNode(ADDRESS_FIELD)
                .addConstraintViolation();
        return false;
    }
}
