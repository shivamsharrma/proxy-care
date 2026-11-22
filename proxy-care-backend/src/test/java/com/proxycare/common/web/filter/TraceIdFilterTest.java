package com.proxycare.common.web.filter;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import com.proxycare.common.logging.MdcKeys;
import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.slf4j.MDC;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.mock.web.MockHttpServletResponse;
import tools.jackson.databind.JsonNode;

@ExtendWith(OutputCaptureExtension.class)
class TraceIdFilterTest extends IntegrationTest {

    private final UUID userId = UUID.randomUUID();

    @Test
    void everyResponseGetsAGeneratedUuid() throws Exception {
        String traceId = items().getHeader(TraceIdFilter.TRACE_ID_HEADER);

        assertThat(UUID.fromString(traceId).toString()).isEqualTo(traceId);
    }

    @Test
    void everyRequestGetsADifferentTraceId() throws Exception {
        String first = items().getHeader(TraceIdFilter.TRACE_ID_HEADER);
        String second = items().getHeader(TraceIdFilter.TRACE_ID_HEADER);

        assertThat(first).isNotEqualTo(second);
    }

    /** Even a well-formed UUID from the client is ignored, under either header name. */
    @ParameterizedTest
    @ValueSource(strings = {"X-Trace-Id", "X-Request-Id"})
    void clientSentIdIsNeverUsed(String header) throws Exception {
        String sent = UUID.randomUUID().toString();

        MockHttpServletResponse response = mockMvc.perform(get("/api/v1/_probe/items")
                        .header("Authorization", bearer(userId))
                        .header(header, sent))
                .andReturn()
                .getResponse();

        assertThat(response.getHeader(TraceIdFilter.TRACE_ID_HEADER)).isNotEqualTo(sent);
        assertThat(response.getHeaderValues(TraceIdFilter.TRACE_ID_HEADER)).hasSize(1);
        assertThat(response.getContentAsString()).doesNotContain(sent);
    }

    @Test
    void injectionAttemptIsNotEchoed() throws Exception {
        MockHttpServletResponse response = mockMvc.perform(get("/api/v1/_probe/items")
                        .header("Authorization", bearer(userId))
                        .header(TraceIdFilter.TRACE_ID_HEADER, "abc\r\nSet-Cookie: evil=1"))
                .andReturn()
                .getResponse();

        assertThat(response.getHeader(TraceIdFilter.TRACE_ID_HEADER)).doesNotContain("abc");
        assertThat(response.getHeader("Set-Cookie")).isNull();
    }

    @Test
    void errorBodyTraceIdMatchesHeader() throws Exception {
        MockHttpServletResponse response = mockMvc.perform(get("/api/v1/_probe/not-found").header("Authorization", bearer(userId)))
                .andReturn()
                .getResponse();

        assertBodyTraceIdMatchesHeader(response);
    }

    /** The filter runs before Spring Security, so its 401s carry the trace ID too. */
    @Test
    void unauthenticatedErrorAlsoCarriesTheTraceId() throws Exception {
        MockHttpServletResponse response = mockMvc.perform(get("/api/v1/_probe/whoami")).andReturn().getResponse();

        assertThat(response.getStatus()).isEqualTo(401);
        assertBodyTraceIdMatchesHeader(response);
    }

    @Test
    void accessLogLineCarriesTheTraceId(CapturedOutput output) throws Exception {
        String traceId = items().getHeader(TraceIdFilter.TRACE_ID_HEADER);

        assertThat(output.getOut().lines()
                        .filter(line -> line.contains("GET /api/v1/_probe/items 200"))
                        .filter(line -> line.contains(traceId)))
                .hasSize(1);
    }

    @Test
    void traceIdIsRemovedFromTheMdcAfterTheRequest() throws Exception {
        items();

        assertThat(MDC.get(MdcKeys.TRACE_ID)).isNull();
    }

    private MockHttpServletResponse items() throws Exception {
        return mockMvc.perform(get("/api/v1/_probe/items").header("Authorization", bearer(userId)))
                .andReturn()
                .getResponse();
    }

    private void assertBodyTraceIdMatchesHeader(MockHttpServletResponse response) throws Exception {
        JsonNode body = objectMapper.readTree(response.getContentAsString());
        assertThat(body.get("meta").get("traceId").asString())
                .isEqualTo(response.getHeader(TraceIdFilter.TRACE_ID_HEADER));
    }
}
