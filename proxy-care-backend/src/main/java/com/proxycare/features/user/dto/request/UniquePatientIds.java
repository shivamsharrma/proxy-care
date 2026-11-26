package com.proxycare.features.user.dto.request;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/** No two entries of a patients list name the same patient id; new patients (no id) are not compared. */
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = UniquePatientIdsValidator.class)
public @interface UniquePatientIds {

    String message() default "must not list the same patient twice";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
