package com.proxycare.features.caretaker.service;

import com.proxycare.common.exception.FieldValidationException;
import com.proxycare.common.model.MobileNumber;
import com.proxycare.features.caretaker.dto.request.SaveBasicInformationRequest;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import java.util.Map;
import java.util.TreeMap;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * Checks stored C2 basic information the way controller-level {@code @Valid} would, plus the rule that needs the
 * caller: the emergency contact differs from the caretaker's own mobile. It runs in the service because the draft
 * is stored before validation (decision OQ-2).
 */
@Component
@RequiredArgsConstructor
public class BasicInformationValidator {

    private static final String EMERGENCY_CONTACT_NUMBER_FIELD = "emergencyContact.number";
    private static final String OWN_MOBILE_NUMBER_MESSAGE = "must be different from your own mobile number";
    private static final String E164_PREFIX = "+";

    private final Validator validator;

    /** Throws FieldValidationException (400 VALIDATION_FAILED, one message per field) when anything is invalid. */
    public void validate(SaveBasicInformationRequest saveBasicInformationRequest, String ownPhoneClaim) {
        Map<String, String> fieldErrors = new TreeMap<>();
        for (ConstraintViolation<SaveBasicInformationRequest> constraintViolation
                : validator.validate(saveBasicInformationRequest)) {
            fieldErrors.putIfAbsent(constraintViolation.getPropertyPath().toString(), constraintViolation.getMessage());
        }
        if (isOwnMobileNumber(saveBasicInformationRequest.emergencyContact(), ownPhoneClaim)) {
            fieldErrors.putIfAbsent(EMERGENCY_CONTACT_NUMBER_FIELD, OWN_MOBILE_NUMBER_MESSAGE);
        }

        if (!fieldErrors.isEmpty()) {
            throw new FieldValidationException(fieldErrors);
        }
    }

    /** Supabase's phone claim may lack the leading +, e.g. 919988776655; the MobileNumber is +91 and 9988776655. */
    private static boolean isOwnMobileNumber(MobileNumber mobileNumber, String ownPhoneClaim) {
        if (mobileNumber == null || mobileNumber.countryCode() == null || mobileNumber.number() == null
                || ownPhoneClaim == null) {
            return false;
        }
        String ownE164Phone = ownPhoneClaim.startsWith(E164_PREFIX) ? ownPhoneClaim : E164_PREFIX + ownPhoneClaim;
        return ownE164Phone.equals(mobileNumber.countryCode() + mobileNumber.number());
    }
}
