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
    public Optional<AuthenticatedPrincipal> getCurrentPrincipal() {
        return Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication())
                .filter(Authentication::isAuthenticated)
                .map(Authentication::getPrincipal)
                .filter(AuthenticatedPrincipal.class::isInstance)
                .map(AuthenticatedPrincipal.class::cast);
    }

    @Override
    public AuthenticatedPrincipal requireCurrentPrincipal() {
        return getCurrentPrincipal()
                .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHENTICATED, SecurityMessages.UNAUTHENTICATED));
    }

}
