package com.proxycare.common.security.handler;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.common.exception.handler.ApiErrorFactory;
import com.proxycare.common.exception.handler.ApiErrorResponseWriter;
import com.proxycare.common.logging.MdcKeys;
import com.proxycare.support.MutableClock;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

class SecurityHandlersTest {

    private final JsonMapper jsonMapper = JsonMapper.builder().build();
    private final ApiErrorResponseWriter apiErrorResponseWriter =
            new ApiErrorResponseWriter(new ApiErrorFactory(new MutableClock()), jsonMapper);

    private final MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/_probe/whoami");
    private final MockHttpServletResponse response = new MockHttpServletResponse();

    @BeforeEach
    void setTraceId() {
        MDC.put(MdcKeys.TRACE_ID, "trace-1");
    }

    @AfterEach
    void clearMdc() {
        MDC.clear();
    }

    @Test
    void entryPointWritesUnauthenticated() throws Exception {
        new RestAuthenticationEntryPoint(apiErrorResponseWriter)
                .commence(request, response, new BadCredentialsException("secret detail"));

        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(response.getHeader("WWW-Authenticate")).isEqualTo("Bearer");
        assertError("UNAUTHENTICATED");
        assertThat(response.getContentAsString()).doesNotContain("secret detail");
    }

    @Test
    void accessDeniedHandlerWritesAccessDenied() throws Exception {
        new RestAccessDeniedHandler(apiErrorResponseWriter)
                .handle(request, response, new AccessDeniedException("secret detail"));

        assertThat(response.getStatus()).isEqualTo(403);
        assertError("ACCESS_DENIED");
        assertThat(response.getContentAsString()).doesNotContain("secret detail");
    }

    private void assertError(String code) throws Exception {
        assertThat(response.getContentType()).startsWith("application/json");
        JsonNode body = jsonMapper.readTree(response.getContentAsString());
        assertThat(body.get("code").asString()).isEqualTo(code);
        assertThat(body.get("message").asString()).isNotBlank();
        assertThat(body.get("meta").get("traceId").asString()).isEqualTo("trace-1");
        assertThat(body.get("meta").get("timestamp").asString())
                .isEqualTo(MutableClock.DEFAULT_INSTANT.toString());
    }
}
