package in.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import in.proxycare.shared.integration.HttpClientSettings;
import in.proxycare.shared.integration.RestClientFactory;
import java.net.ConnectException;
import java.net.URI;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

/**
 * Proves the guard works: an outbound request to a real internet host fails locally. The target is
 * IANA's reserved example.com, not a vendor, so even a broken guard calls no vendor.
 */
class VendorCallGuardTest {

  @Test
  void isActiveForTheWholeTestRun() {
    assertThat(System.getProperty("https.proxyHost")).isEqualTo(VendorCallGuard.DEAD_PROXY_HOST);
    assertThat(System.getProperty("http.nonProxyHosts")).isEqualTo(VendorCallGuard.LOCAL_HOSTS);
  }

  @Test
  void refusesRequestsToNonLocalHosts() {
    RestClient client =
        new RestClientFactory(RestClient.builder(), TestJson.mapper())
            .create(
                new HttpClientSettings(
                    URI.create("https://example.com"),
                    Duration.ofSeconds(2),
                    Duration.ofSeconds(2)));

    assertThatThrownBy(() -> client.get().uri("/").retrieve().toBodilessEntity())
        .isInstanceOf(ResourceAccessException.class)
        .hasCauseInstanceOf(ConnectException.class);
  }
}
