package com.proxycare.common.web.filter;

import com.proxycare.common.logging.MdcKeys;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Objects;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
@Order(FilterOrder.REQUEST_LOGGING)
public class RequestLoggingFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(RequestLoggingFilter.class);

    private static final String HEALTH_PATH = "/actuator/health";
    private static final String NO_TRACE_ID = "-";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        long startNanos = System.nanoTime();
        try {
            chain.doFilter(request, response);
        } finally {
            if (!isHealthCheck(request)) {
                logCompletedRequest(request, response, elapsedMillis(startNanos));
            }
        }
    }

    private static boolean isHealthCheck(HttpServletRequest request) {
        return request.getRequestURI().startsWith(HEALTH_PATH);
    }

    private static long elapsedMillis(long startNanos) {
        return (System.nanoTime() - startNanos) / 1_000_000;
    }

    private static void logCompletedRequest(
            HttpServletRequest request, HttpServletResponse response, long elapsedMillis) {
        log.info(
                "{} {} {} {}ms traceId={}",
                request.getMethod(),
                request.getRequestURI(),
                response.getStatus(),
                elapsedMillis,
                currentTraceId());
    }

    private static String currentTraceId() {
        return Objects.requireNonNullElse(MDC.get(MdcKeys.TRACE_ID), NO_TRACE_ID);
    }
}
