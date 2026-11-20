package com.proxycare.common.web.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Marks every API response {@code Cache-Control: no-store}: they hold personal data, so no browser,
 * proxy or CDN may keep a copy. Other paths keep Spring Security's default header.
 */
@Component
@Order(FilterOrder.API_CACHE_CONTROL)
public class ApiCacheControlFilter extends OncePerRequestFilter {

    private static final String API_PATH_PREFIX = "/api/";
    private static final String NO_STORE = "no-store";

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !isApiRequest(request);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        response.setHeader(HttpHeaders.CACHE_CONTROL, NO_STORE);
        chain.doFilter(request, response);
    }

    private static boolean isApiRequest(HttpServletRequest request) {
        return request.getRequestURI().startsWith(API_PATH_PREFIX);
    }
}
