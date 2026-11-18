package in.proxycare.shared.api;

import java.time.Duration;
import java.util.Objects;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.util.unit.DataSize;

/**
 * HTTP API limits (ADR 0012).
 *
 * @param maxRequestBodySize largest accepted request body; larger bodies get 413
 * @param defaultRetryAfter {@code Retry-After} for 429/503 responses when the cause gives no better
 *     value
 */
@ConfigurationProperties("proxycare.api")
public record ApiProperties(DataSize maxRequestBodySize, Duration defaultRetryAfter) {

  public ApiProperties {
    Objects.requireNonNull(maxRequestBodySize, "proxycare.api.max-request-body-size is required");
    Objects.requireNonNull(defaultRetryAfter, "proxycare.api.default-retry-after is required");
    if (maxRequestBodySize.toBytes() <= 0) {
      throw new IllegalArgumentException("proxycare.api.max-request-body-size must be positive");
    }
    if (defaultRetryAfter.isNegative() || defaultRetryAfter.isZero()) {
      throw new IllegalArgumentException("proxycare.api.default-retry-after must be positive");
    }
  }
}
