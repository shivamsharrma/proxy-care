package com.proxycare.common.security.identity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.security.authorization.Role;
import java.util.EnumSet;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

class SpringSecurityIdentityProviderTest {

    private final SpringSecurityIdentityProvider springSecurityIdentityProvider = new SpringSecurityIdentityProvider();
    private final UUID userId = UUID.randomUUID();

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void returnsThePrincipalOfTheAuthenticatedCaller() {
        var principal = new AuthenticatedPrincipal(userId, "+919876543210", EnumSet.of(Role.CARETAKER));
        SecurityContextHolder.getContext()
                .setAuthentication(UsernamePasswordAuthenticationToken.authenticated(principal, null, List.of()));

        assertThat(springSecurityIdentityProvider.getCurrentPrincipal()).contains(principal);
        assertThat(springSecurityIdentityProvider.requireCurrentUserId()).isEqualTo(userId);
        assertThat(springSecurityIdentityProvider.hasRole(Role.CARETAKER)).isTrue();
        assertThat(springSecurityIdentityProvider.hasRole(Role.ADMIN)).isFalse();
    }

    @Test
    void emptyWithoutAuthentication() {
        assertThat(springSecurityIdentityProvider.getCurrentPrincipal()).isEmpty();
        assertThat(springSecurityIdentityProvider.hasRole(Role.USER)).isFalse();
    }

    @Test
    void anonymousCallerIsNotAPrincipal() {
        SecurityContextHolder.getContext().setAuthentication(new AnonymousAuthenticationToken(
                "key", "anonymousUser", List.of(new SimpleGrantedAuthority("ROLE_ANONYMOUS"))));

        assertThat(springSecurityIdentityProvider.getCurrentPrincipal()).isEmpty();
    }

    @Test
    void requireThrowsUnauthenticatedWithoutACaller() {
        assertThatThrownBy(springSecurityIdentityProvider::requireCurrentPrincipal)
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo(ErrorCode.UNAUTHENTICATED);
    }
}
