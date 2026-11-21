package com.proxycare.common.security.handler;

import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.exception.handler.ApiErrorResponseWriter;
import com.proxycare.common.security.SecurityMessages;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;

/**
 * 401 for a missing, expired or invalid token, in the same ApiError JSON as every other error. Why the
 * token failed is never sent back: it would help an attacker more than a client.
 */
@Component
@RequiredArgsConstructor
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private static final String BEARER_CHALLENGE = "Bearer";

    private final ApiErrorResponseWriter apiErrorResponseWriter;

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response, AuthenticationException ex)
            throws IOException {
        response.setHeader(HttpHeaders.WWW_AUTHENTICATE, BEARER_CHALLENGE);
        apiErrorResponseWriter.write(response, ErrorCode.UNAUTHENTICATED, SecurityMessages.UNAUTHENTICATED);
    }

}
