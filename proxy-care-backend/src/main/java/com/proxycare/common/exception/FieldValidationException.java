package com.proxycare.common.exception;

import java.util.Collections;
import java.util.Map;
import java.util.TreeMap;
import lombok.Getter;

/**
 * Field rules a service checks itself (on stored input, or against the caller or the clock), answered exactly like
 * Bean Validation: 400 VALIDATION_FAILED with {@code fieldErrors} sorted by field. Messages never hold the values.
 */
@Getter
public class FieldValidationException extends ServiceInputException {

    private static final String MESSAGE = "Validation failed";

    private final Map<String, String> fieldErrors;

    public FieldValidationException(Map<String, String> fieldErrors) {
        super(ErrorCode.VALIDATION_FAILED, MESSAGE);
        this.fieldErrors = Collections.unmodifiableMap(new TreeMap<>(fieldErrors));
    }

    public FieldValidationException(String field, String message) {
        this(Map.of(field, message));
    }
}
