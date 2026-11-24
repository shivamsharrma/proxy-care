package com.proxycare.features.patient.dto.request;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/** A type-level constraint that reports its error on the {@code address} field, like a field constraint. */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = OwnAddressRequiredValidator.class)
public @interface OwnAddressRequired {

    String message() default "is required when the patient does not live at your address";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
