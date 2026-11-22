package com.proxycare.common.web.filter;

import com.proxycare.common.logging.MdcKeys;
import com.proxycare.common.security.identity.AuthenticatedUser;
import com.proxycare.common.security.identity.ISecurityIdentityProvider;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import lombok.RequiredArgsConstructor;
import org.slf4j.MDC;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
@Order(FilterOrder.USER_ID)
@RequiredArgsConstructor
public class UserIdMdcFilter extends OncePerRequestFilter {

    private final ISecurityIdentityProvider securityIdentityProvider;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        addUserIdToLogContext();
        try {
            chain.doFilter(request, response);
        } finally {
            removeUserIdFromLogContext();
        }
    }

    private void addUserIdToLogContext() {
        securityIdentityProvider.findAuthenticatedUser()
                .map(AuthenticatedUser::userId)
                .ifPresent(userId -> MDC.put(MdcKeys.USER_ID, userId.toString()));
    }

    private static void removeUserIdFromLogContext() {
        MDC.remove(MdcKeys.USER_ID);
    }
}
