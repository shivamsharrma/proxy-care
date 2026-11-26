package com.proxycare.features.user.dto.request;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;

public class UniquePatientIdsValidator implements ConstraintValidator<UniquePatientIds, List<SavePatientRequest>> {

    @Override
    public boolean isValid(
            List<SavePatientRequest> savePatientRequests, ConstraintValidatorContext constraintValidatorContext) {
        // A missing list or a null entry is reported by its own @NotNull.
        if (savePatientRequests == null) {
            return true;
        }

        Set<UUID> patientIds = new HashSet<>();
        return savePatientRequests.stream()
                .filter(Objects::nonNull)
                .map(SavePatientRequest::id)
                .filter(Objects::nonNull)
                .allMatch(patientIds::add);
    }
}
