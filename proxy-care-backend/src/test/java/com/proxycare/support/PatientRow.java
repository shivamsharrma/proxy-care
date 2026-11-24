package com.proxycare.support;

import java.util.UUID;

/**
 * A patients row as stored, read by {@link TestDb#patientsOf(UUID)}; relation, sex and mobility are the enum
 * names. {@code userId} is the owning app_users id.
 */
public record PatientRow(
        UUID id,
        UUID userId,
        String relation,
        String fullName,
        Integer age,
        String sex,
        String mobileCountryCode,
        String mobileNumber,
        Boolean livesAtUserAddress,
        String address,
        String mobility,
        String healthNotes) {}
