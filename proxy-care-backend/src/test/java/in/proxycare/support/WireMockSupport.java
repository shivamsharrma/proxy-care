package in.proxycare.support;

import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.wireMockConfig;

import com.github.tomakehurst.wiremock.junit5.WireMockExtension;
import in.proxycare.shared.integration.HttpClientSettings;
import java.net.URI;
import java.time.Duration;

/**
 * WireMock servers that stand in for vendor APIs.
 *
 * <pre>{@code
 * @RegisterExtension
 * static final WireMockExtension razorpay = WireMockSupport.newServer();
 * }</pre>
 *
 * <p>Each server listens on a random local port, is reset between tests by the extension, and fails
 * the test if the code sends a request no stub expects, so an unexpected vendor call is a test
 * failure rather than a silent 404.
 */
public final class WireMockSupport {

  /**
   * Generous defaults: a cold JVM's first request (class loading in client and WireMock) must not
   * trip them. Tests about timeouts pass their own short value explicitly.
   */
  public static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(5);

  public static final Duration READ_TIMEOUT = Duration.ofSeconds(10);

  private WireMockSupport() {}

  public static WireMockExtension newServer() {
    return WireMockExtension.newInstance()
        .options(wireMockConfig().dynamicPort())
        .failOnUnmatchedRequests(true)
        .build();
  }

  /** Client settings pointing at {@code server}, with short test timeouts. */
  public static HttpClientSettings clientSettings(WireMockExtension server) {
    return clientSettings(server, READ_TIMEOUT);
  }

  public static HttpClientSettings clientSettings(WireMockExtension server, Duration readTimeout) {
    return new HttpClientSettings(URI.create(server.baseUrl()), CONNECT_TIMEOUT, readTimeout);
  }
}
