package com.proxycare.support;

import java.time.Instant;
import java.util.UUID;

/**
 * A patients row as stored, read by {@link TestDb#patientsOf(UUID)}; relation, sex and mobilityCategory are the enum
 * names. {@code userId} is the owning app_users id; {@code deletedAt} is null for a live patient.
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
        String address,
        String mobilityCategory,
        String healthNotes,
        Instant deletedAt) {}
