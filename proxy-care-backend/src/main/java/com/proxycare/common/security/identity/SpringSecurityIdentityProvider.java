package com.proxycare.common.security.identity;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.security.SecurityMessages;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.util.Optional;

/** Reads the caller from the SecurityContext, where {@code SupabaseJwtAuthenticationConverter} put it. */
@Component
public class SpringSecurityIdentityProvider implements ISecurityIdentityProvider {

    @Override
    public Optional<AuthenticatedUser> findAuthenticatedUser() {
        return Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication())
                .filter(Authentication::isAuthenticated)
                .map(Authentication::getPrincipal)
                .filter(AuthenticatedUser.class::isInstance)
                .map(AuthenticatedUser.class::cast);
    }

    @Override
    public AuthenticatedUser getAuthenticatedUser() {
        return findAuthenticatedUser()
                .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHENTICATED, SecurityMessages.UNAUTHENTICATED));
    }

}
