package com.proxycare.features.user.dto.response;

import java.util.UUID;

/**
 * What other features need to link a record to the caller's user profile: the owner id, and the current address
 * for copying (a patient who lives with the user). Returned by IAppUserService only, never sent to the apps.
 */
public record AppUserReferenceResponse(
        UUID appUserId,
        String address
) {}
