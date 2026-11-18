package in.proxycare.shared.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;
import static org.assertj.core.api.Assertions.assertThatNullPointerException;

import java.net.URI;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/** Example unit test: no Spring, no I/O, Arrange-Act-Assert, boundaries and failures. */
class HttpClientSettingsTest {

  private static final URI VENDOR = URI.create("https://api.vendor.example/v1");
  private static final Duration ONE_SECOND = Duration.ofSeconds(1);

  @Test
  void acceptsAnAbsoluteHttpsUrlAndPositiveTimeouts() {
    // Arrange
    Duration connect = Duration.ofMillis(1);
    Duration read = Duration.ofSeconds(30);

    // Act
    HttpClientSettings settings = new HttpClientSettings(VENDOR, connect, read);

    // Assert
    assertThat(settings.baseUrl()).isEqualTo(VENDOR);
    assertThat(settings.connectTimeout()).isEqualTo(connect);
    assertThat(settings.readTimeout()).isEqualTo(read);
  }

  @Test
  void acceptsPlainHttpForLocalStubs() {
    URI wiremock = URI.create("http://localhost:8089");

    HttpClientSettings settings = new HttpClientSettings(wiremock, ONE_SECOND, ONE_SECOND);

    assertThat(settings.baseUrl()).isEqualTo(wiremock);
  }

  @ParameterizedTest
  @ValueSource(strings = {"/v1/orders", "ftp://files.vendor.example", "api.vendor.example"})
  void rejectsUrlsThatAreNotAbsoluteHttp(String url) {
    URI uri = URI.create(url);

    assertThatIllegalArgumentException()
        .isThrownBy(() -> new HttpClientSettings(uri, ONE_SECOND, ONE_SECOND))
        .withMessage("baseUrl must be an absolute http(s) URL");
  }

  @Test
  void rejectsAZeroConnectTimeout() {
    assertThatIllegalArgumentException()
        .isThrownBy(() -> new HttpClientSettings(VENDOR, Duration.ZERO, ONE_SECOND))
        .withMessage("connectTimeout must be positive");
  }

  @Test
  void rejectsANegativeReadTimeout() {
    Duration negative = Duration.ofMillis(-1);

    assertThatIllegalArgumentException()
        .isThrownBy(() -> new HttpClientSettings(VENDOR, ONE_SECOND, negative))
        .withMessage("readTimeout must be positive");
  }

  @Test
  void requiresEverySetting() {
    assertThatNullPointerException()
        .isThrownBy(() -> new HttpClientSettings(null, ONE_SECOND, ONE_SECOND))
        .withMessage("baseUrl");
    assertThatNullPointerException()
        .isThrownBy(() -> new HttpClientSettings(VENDOR, null, ONE_SECOND))
        .withMessage("connectTimeout");
    assertThatNullPointerException()
        .isThrownBy(() -> new HttpClientSettings(VENDOR, ONE_SECOND, null))
        .withMessage("readTimeout");
  }
}
