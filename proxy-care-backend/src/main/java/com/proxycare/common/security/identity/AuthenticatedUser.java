package com.proxycare.common.security.identity;

import com.proxycare.common.security.authorization.Role;

import java.util.Objects;
import java.util.Set;
import java.util.UUID;

/**
 * The verified caller of the current request.
 *
 * @param userId Supabase user id (the token's {@code sub}); decide whose data to touch from this only
 * @param phone  the token's {@code phone} claim; personal data, never log it
 * @param roles  empty until the user has a profile (still onboarding)
 */
public record AuthenticatedUser(
        UUID userId,
        String phone,
        Set<Role> roles
) {

    public AuthenticatedUser {
        Objects.requireNonNull(userId, "userId");
        roles = roles == null ? Set.of() : Set.copyOf(roles);
    }

    public boolean hasRole(Role role) {
        return roles.contains(role);
    }

}
