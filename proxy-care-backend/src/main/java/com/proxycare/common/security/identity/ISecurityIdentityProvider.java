package com.proxycare.common.security.identity;

import com.proxycare.common.security.authorization.Role;

import java.util.Optional;
import java.util.UUID;

/**
 * Who is calling. Services depend on this instead of Spring Security, so they stay easy to test.
 */
public interface ISecurityIdentityProvider {

    /** Empty on public endpoints and outside a request. */
    Optional<AuthenticatedUser> findAuthenticatedUser();

    /** The caller; throws UNAUTHENTICATED when there is none. */
    AuthenticatedUser getAuthenticatedUser();

    
    default UUID getAuthenticatedUserId() {
        return getAuthenticatedUser().userId();
    }

    default boolean hasRole(Role role) {
        return findAuthenticatedUser()
                .map(authenticatedUser -> authenticatedUser.hasRole(role))
                .orElse(false);
    }

}
