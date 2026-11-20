package com.proxycare.common.web.filter;

import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.exception.handler.ApiErrorResponseWriter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.util.unit.DataSize;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
@Order(FilterOrder.REQUEST_BODY_SIZE_LIMIT)
public class RequestBodySizeLimitFilter extends OncePerRequestFilter {

    static final long MAX_BODY_BYTES = DataSize.ofMegabytes(1).toBytes();

    private static final String TOO_LARGE_MESSAGE = "The request body is larger than 1 MB";

    private final ApiErrorResponseWriter errors;

    public RequestBodySizeLimitFilter(ApiErrorResponseWriter errors) {
        this.errors = errors;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        if (isTooLarge(request)) {
            errors.write(response, ErrorCode.PAYLOAD_TOO_LARGE, TOO_LARGE_MESSAGE);
            return;
        }
        chain.doFilter(request, response);
    }

    private static boolean isTooLarge(HttpServletRequest request) {
        return request.getContentLengthLong() > MAX_BODY_BYTES;
    }
}
