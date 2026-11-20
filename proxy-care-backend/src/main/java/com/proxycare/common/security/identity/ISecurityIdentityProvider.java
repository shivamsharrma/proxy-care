package com.proxycare.common.security.identity;

import com.proxycare.common.security.authorization.Role;

import java.util.Optional;
import java.util.UUID;

/**
 * Who is calling. Services depend on this instead of Spring Security, so they stay easy to test.
 */
public interface ISecurityIdentityProvider {

    /** Empty on public endpoints and outside a request. */
    Optional<AuthenticatedPrincipal> getCurrentPrincipal();

    /** The caller; throws UNAUTHENTICATED when there is none. */
    AuthenticatedPrincipal requireCurrentPrincipal();

    default UUID requireCurrentUserId() {
        return requireCurrentPrincipal().userId();
    }

    default boolean hasRole(Role role) {
        return getCurrentPrincipal()
                .map(principal -> principal.hasRole(role))
                .orElse(false);
    }

}
