package com.proxycare.common.security.authorization;

import java.util.Set;
import java.util.UUID;

/**
 * A user's roles, read on every authenticated request so a role change applies on the next call. Implemented by
 * the feature that owns the roles, so security never depends on a feature.
 */
public interface IUserRoleProvider {

    /** Empty when the user has no profile yet (still onboarding). */
    Set<Role> findRoles(UUID userId);
}
