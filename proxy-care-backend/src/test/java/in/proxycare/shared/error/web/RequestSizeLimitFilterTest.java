package in.proxycare.shared.error.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import in.proxycare.shared.error.ErrorCode;
import in.proxycare.support.MutableClock;
import io.micrometer.tracing.Tracer;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.support.StaticListableBeanFactory;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import tools.jackson.databind.json.JsonMapper;

/**
 * The size limit for bodies whose length is unknown in advance (chunked transfer), which MockMvc
 * cannot send: those are counted while read. Declared lengths are covered end to end in
 * ProblemResponseContractTest.
 */
class RequestSizeLimitFilterTest {

  private static final int LIMIT = 16;

  private final ProblemResponseWriter writer =
      new ProblemResponseWriter(
          new ProblemFactory(
              new MutableClock(),
              new TraceIdProvider(new StaticListableBeanFactory().getBeanProvider(Tracer.class))),
          JsonMapper.builder().build());
  private final RequestSizeLimitFilter filter = new RequestSizeLimitFilter(LIMIT, writer);

  @Test
  void letsABodyAtTheLimitThrough() throws Exception {
    MockHttpServletRequest request = chunked(new byte[LIMIT]);
    AtomicBoolean read = new AtomicBoolean();

    filter.doFilter(
        request,
        new MockHttpServletResponse(),
        (req, res) -> {
          req.getInputStream().readAllBytes();
          read.set(true);
        });

    assertThat(read).isTrue();
  }

  @Test
  void failsTheReadOnceAChunkedBodyCrossesTheLimit() {
    MockHttpServletRequest request = chunked(new byte[LIMIT + 1]);

    assertThatThrownBy(() ->
            filter.doFilter(
                request,
                new MockHttpServletResponse(),
                (req, res) -> {
                  try (InputStream body = req.getInputStream()) {
                    body.readAllBytes();
                  }
                }))
        .isInstanceOf(IOException.class)
        .satisfies(failure -> assertThat(RequestSizeLimitFilter.isTooLarge(failure)).isTrue());
  }

  @Test
  void refusesADeclaredLengthOverTheLimitWithoutReading() throws Exception {
    MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/things");
    request.setContent(new byte[LIMIT + 1]);
    MockHttpServletResponse response = new MockHttpServletResponse();
    AtomicBoolean reachedTheApplication = new AtomicBoolean();

    filter.doFilter(request, response, (req, res) -> reachedTheApplication.set(true));

    assertThat(reachedTheApplication).isFalse();
    assertThat(response.getStatus()).isEqualTo(ErrorCode.PAYLOAD_TOO_LARGE.status());
    assertThat(response.getContentType()).startsWith("application/problem+json");
    assertThat(response.getContentAsString()).contains("\"code\":\"PAYLOAD_TOO_LARGE\"");
  }

  @Test
  void recognisesOnlyItsOwnFailure() {
    assertThat(RequestSizeLimitFilter.isTooLarge(new IOException("connection reset"))).isFalse();
  }

  /** A request whose length is not declared, like a chunked upload. */
  private static MockHttpServletRequest chunked(byte[] body) {
    MockHttpServletRequest request =
        new MockHttpServletRequest("POST", "/api/v1/things") {
          @Override
          public long getContentLengthLong() {
            return -1;
          }

          @Override
          public int getContentLength() {
            return -1;
          }
        };
    request.setContent(body);
    return request;
  }
}
