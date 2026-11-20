package com.proxycare.common.exception.handler;

import com.proxycare.common.exception.ErrorCode;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/**
 * Writes an ApiError straight to the servlet response, for errors raised before Spring MVC runs (filters and
 * Spring Security), so they look the same as errors from controllers.
 */
@Component
@RequiredArgsConstructor
public class ApiErrorResponseWriter {

    private final ApiErrorFactory apiErrors;
    private final JsonMapper jsonMapper;

    public void write(HttpServletResponse response, ErrorCode errorCode, String message) throws IOException {
        response.setStatus(errorCode.getStatus().value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        jsonMapper.writeValue(response.getOutputStream(), apiErrors.create(errorCode, message));
    }
}
