package com.proxycare.common.web;

import com.proxycare.common.error.ErrorCode;
import com.proxycare.common.error.GlobalExceptionHandler;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Objects;
import java.util.UUID;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Runs first. Assigns the requestId, rejects bodies over 1 MB, marks API responses no-store and logs
 * one access line per request. Never logs bodies, query strings or headers.
 *
 * <p>Known limitation: the size check reads Content-Length, so a chunked body without it is not
 * caught here. The load balancer or proxy must also enforce a body limit in production.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestLoggingFilter extends OncePerRequestFilter {

    public static final String REQUEST_ID_HEADER = "X-Request-Id";
    static final long MAX_BODY_BYTES = 1024 * 1024;

    private static final Logger log = LoggerFactory.getLogger(RequestLoggingFilter.class);
    // Only a canonical UUID is accepted, which blocks log and header injection.
    private static final Pattern UUID_PATTERN =
            Pattern.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$");

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String requestId = request.getHeader(REQUEST_ID_HEADER);
        if (requestId == null || !UUID_PATTERN.matcher(requestId).matches()) {
            requestId = UUID.randomUUID().toString();
        }
        MDC.put("requestId", requestId);
        response.setHeader(REQUEST_ID_HEADER, requestId);
        long start = System.nanoTime();
        try {
            if (request.getRequestURI().startsWith("/api/")) {
                response.setHeader("Cache-Control", "no-store");
            }
            if (request.getContentLengthLong() > MAX_BODY_BYTES) {
                GlobalExceptionHandler.writeProblem(
                        request, response, ErrorCode.PAYLOAD_TOO_LARGE, "The request body is larger than 1 MB.");
                return;
            }
            chain.doFilter(request, response);
        } finally {
            if (!request.getRequestURI().startsWith("/actuator/health")) {
                log.info(
                        "{} {} {} {}ms user={}",
                        request.getMethod(),
                        request.getRequestURI(),
                        response.getStatus(),
                        (System.nanoTime() - start) / 1_000_000,
                        Objects.requireNonNullElse(MDC.get("userId"), "-"));
            }
            MDC.clear();
        }
    }
}
