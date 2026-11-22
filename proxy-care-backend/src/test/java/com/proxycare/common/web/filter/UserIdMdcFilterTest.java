package com.proxycare.common.web.filter;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.common.logging.MdcKeys;
import com.proxycare.common.security.identity.AuthenticatedUser;
import com.proxycare.common.security.identity.ISecurityIdentityProvider;
import jakarta.servlet.FilterChain;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class UserIdMdcFilterTest {

    private final UUID userId = UUID.randomUUID();
    private final AtomicReference<String> userIdDuringRequest = new AtomicReference<>();
    private final FilterChain filterChain = (request, response) -> userIdDuringRequest.set(MDC.get(MdcKeys.USER_ID));

    @AfterEach
    void clearMdc() {
        MDC.clear();
    }

    @Test
    void authenticatedRequestLogsCarryTheUserId() throws Exception {
        run(Optional.of(new AuthenticatedUser(userId, "+919876543210", Set.of())));

        assertThat(userIdDuringRequest.get()).isEqualTo(userId.toString());
    }

    @Test
    void userIdIsRemovedWhenTheRequestEnds() throws Exception {
        run(Optional.of(new AuthenticatedUser(userId, "+919876543210", Set.of())));

        assertThat(MDC.get(MdcKeys.USER_ID)).isNull();
    }

    @Test
    void anonymousRequestHasNoUserId() throws Exception {
        run(Optional.empty());

        assertThat(userIdDuringRequest.get()).isNull();
    }

    private void run(Optional<AuthenticatedUser> authenticatedUser) throws Exception {
        new UserIdMdcFilter(identityReturning(authenticatedUser))
                .doFilter(new MockHttpServletRequest(), new MockHttpServletResponse(), filterChain);
    }

    private static ISecurityIdentityProvider identityReturning(Optional<AuthenticatedUser> authenticatedUser) {
        return new ISecurityIdentityProvider() {
            @Override
            public Optional<AuthenticatedUser> findAuthenticatedUser() {
                return authenticatedUser;
            }

            @Override
            public AuthenticatedUser getAuthenticatedUser() {
                return authenticatedUser.orElseThrow();
            }
        };
    }
}
