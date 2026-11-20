package com.proxycare.common.security.handler;

import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.exception.handler.ApiErrorResponseWriter;
import com.proxycare.common.security.SecurityMessages;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;

/**
 * 403 raised in the filter chain, in the same ApiError JSON as every other error. A {@code @PreAuthorize}
 * failure inside a controller is answered by {@code GlobalExceptionHandler} with the same body.
 */
@Component
@RequiredArgsConstructor
public class RestAccessDeniedHandler implements AccessDeniedHandler {

    private final ApiErrorResponseWriter errors;

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response, AccessDeniedException ex)
            throws IOException {
        errors.write(response, ErrorCode.ACCESS_DENIED, SecurityMessages.ACCESS_DENIED);
    }

}
