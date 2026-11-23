package com.proxycare.support;

import java.util.UUID;

/** An app_users row as stored, read by {@link TestDb#appUserOf(UUID)}; sex is the enum name. */
public record AppUserRow(UUID id, UUID profileId, String fullName, String sex, Integer age, String address) {}
