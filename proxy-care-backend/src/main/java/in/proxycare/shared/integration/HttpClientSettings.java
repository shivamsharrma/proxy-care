package in.proxycare.shared.integration;

import java.net.URI;
import java.time.Duration;
import java.util.Objects;

/**
 * Connection settings every outbound HTTP client must state explicitly (ADR 0009): there are no
 * default timeouts.
 *
 * @param baseUrl absolute http(s) URL of the vendor API
 * @param connectTimeout time allowed to open a connection
 * @param readTimeout time allowed for the whole response after the request is sent
 */
public record HttpClientSettings(URI baseUrl, Duration connectTimeout, Duration readTimeout) {

  public HttpClientSettings {
    Objects.requireNonNull(baseUrl, "baseUrl");
    Objects.requireNonNull(connectTimeout, "connectTimeout");
    Objects.requireNonNull(readTimeout, "readTimeout");
    String scheme = baseUrl.getScheme();
    if (!baseUrl.isAbsolute() || !("https".equals(scheme) || "http".equals(scheme))) {
      throw new IllegalArgumentException("baseUrl must be an absolute http(s) URL");
    }
    requirePositive(connectTimeout, "connectTimeout");
    requirePositive(readTimeout, "readTimeout");
  }

  private static void requirePositive(Duration timeout, String name) {
    if (timeout.isZero() || timeout.isNegative()) {
      throw new IllegalArgumentException(name + " must be positive");
    }
  }
}
