package in.proxycare.shared.integration;

import static com.github.tomakehurst.wiremock.client.WireMock.aResponse;
import static com.github.tomakehurst.wiremock.client.WireMock.equalTo;
import static com.github.tomakehurst.wiremock.client.WireMock.equalToJson;
import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.getRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.okJson;
import static com.github.tomakehurst.wiremock.client.WireMock.post;
import static com.github.tomakehurst.wiremock.client.WireMock.postRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.serverError;
import static com.github.tomakehurst.wiremock.client.WireMock.urlPathEqualTo;
import static com.github.tomakehurst.wiremock.stubbing.Scenario.STARTED;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.github.tomakehurst.wiremock.junit5.WireMockExtension;
import in.proxycare.support.IntegrationTest;
import in.proxycare.support.WireMockSupport;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.retry.RetryConfig;
import java.net.http.HttpTimeoutException;
import java.time.Duration;
import java.util.function.Supplier;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.RegisterExtension;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.exc.InvalidFormatException;

/**
 * Example contract test: a real {@link RestClient} from {@link RestClientFactory} talks to a
 * WireMock server standing in for a vendor. Verifies what goes out, what comes back, and how
 * failures surface. Vendor-specific error translation arrives with the first vendor client (ADR
 * 0009); these tests pin the behaviour it builds on.
 */
@IntegrationTest
class RestClientFactoryContractTest {

  @RegisterExtension static final WireMockExtension vendor = WireMockSupport.newServer();

  @Autowired private RestClientFactory factory;

  @Test
  void sendsTheRequestAsJsonAndReadsTheResponse() {
    // Arrange
    vendor.stubFor(
        post(urlPathEqualTo("/v1/orders"))
            .willReturn(
                okJson(
                    """
                    {"id": "order_1", "amount": 109900, "status": "created",
                     "addedByVendorLater": {"nested": true}}
                    """)));
    RestClient client = factory.create(WireMockSupport.clientSettings(vendor));

    // Act
    Order order =
        client
            .post()
            .uri("/v1/orders")
            .header("X-Correlation-Id", "corr-1")
            .body(new CreateOrder(109_900, "INR"))
            .retrieve()
            .body(Order.class);

    // Assert
    assertThat(order).isEqualTo(new Order("order_1", 109_900, "created"));
    vendor.verify(
        postRequestedFor(urlPathEqualTo("/v1/orders"))
            .withHeader("Content-Type", equalTo("application/json"))
            .withHeader("X-Correlation-Id", equalTo("corr-1"))
            .withRequestBody(equalToJson("{\"amount\": 109900, \"currency\": \"INR\"}")));
  }

  @Test
  void rejectsAFractionalAmountFromAVendor() {
    vendor.stubFor(
        get(urlPathEqualTo("/v1/orders/order_1"))
            .willReturn(okJson("{\"id\": \"order_1\", \"amount\": 1099.5, \"status\": \"paid\"}")));
    RestClient client = factory.create(WireMockSupport.clientSettings(vendor));

    assertThatThrownBy(() -> client.get().uri("/v1/orders/order_1").retrieve().body(Order.class))
        .hasRootCauseInstanceOf(InvalidFormatException.class)
        .rootCause()
        .hasMessageContaining("1099.5");
  }

  @Test
  void surfacesClientErrorsWithStatusAndBody() {
    vendor.stubFor(
        post(urlPathEqualTo("/v1/orders"))
            .willReturn(
                aResponse()
                    .withStatus(400)
                    .withHeader("Content-Type", "application/json")
                    .withBody("{\"error\": {\"code\": \"BAD_REQUEST_ERROR\"}}")));
    RestClient client = factory.create(WireMockSupport.clientSettings(vendor));

    assertThatThrownBy(() ->
            client
                .post()
                .uri("/v1/orders")
                .body(new CreateOrder(1, "INR"))
                .retrieve()
                .toBodilessEntity())
        .isInstanceOfSatisfying(
            HttpClientErrorException.class,
            e -> {
              assertThat(e.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
              assertThat(e.getResponseBodyAsString()).contains("BAD_REQUEST_ERROR");
            });
  }

  @Test
  void surfacesServerErrors() {
    vendor.stubFor(get(urlPathEqualTo("/v1/orders/order_1")).willReturn(serverError()));
    RestClient client = factory.create(WireMockSupport.clientSettings(vendor));

    assertThatThrownBy(() -> client.get().uri("/v1/orders/order_1").retrieve().toBodilessEntity())
        .isInstanceOf(HttpServerErrorException.class);
  }

  @Test
  void enforcesTheReadTimeout() {
    // A large margin (5 s delay against a 200 ms timeout) keeps this deterministic.
    vendor.stubFor(get(urlPathEqualTo("/v1/slow")).willReturn(okJson("{}").withFixedDelay(5_000)));
    RestClient client =
        factory.create(WireMockSupport.clientSettings(vendor, Duration.ofMillis(200)));

    assertThatThrownBy(() -> client.get().uri("/v1/slow").retrieve().toBodilessEntity())
        .isInstanceOf(ResourceAccessException.class)
        .hasRootCauseInstanceOf(HttpTimeoutException.class);
  }

  @Test
  void doesNotFollowRedirects() {
    vendor.stubFor(
        get(urlPathEqualTo("/v1/moved"))
            .willReturn(aResponse().withStatus(302).withHeader("Location", "/v1/elsewhere")));
    RestClient client = factory.create(WireMockSupport.clientSettings(vendor));

    ResponseEntity<Void> response = client.get().uri("/v1/moved").retrieve().toBodilessEntity();

    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FOUND);
    vendor.verify(0, getRequestedFor(urlPathEqualTo("/v1/elsewhere")));
  }

  @Test
  void retriesATransientFailureWhenTheCallIsSafeToRepeat() {
    // A read is safe to retry (ADR 0009). Two 503s, then success.
    vendor.stubFor(
        get(urlPathEqualTo("/v1/orders/order_1"))
            .inScenario("flaky")
            .whenScenarioStateIs(STARTED)
            .willReturn(aResponse().withStatus(503))
            .willSetStateTo("failed once"));
    vendor.stubFor(
        get(urlPathEqualTo("/v1/orders/order_1"))
            .inScenario("flaky")
            .whenScenarioStateIs("failed once")
            .willReturn(aResponse().withStatus(503))
            .willSetStateTo("recovered"));
    vendor.stubFor(
        get(urlPathEqualTo("/v1/orders/order_1"))
            .inScenario("flaky")
            .whenScenarioStateIs("recovered")
            .willReturn(okJson("{\"id\": \"order_1\", \"amount\": 100, \"status\": \"paid\"}")));
    RestClient client = factory.create(WireMockSupport.clientSettings(vendor));
    Retry retry =
        Retry.of(
            "contract-test",
            RetryConfig.custom()
                .maxAttempts(3)
                .waitDuration(Duration.ofMillis(1))
                .retryExceptions(HttpServerErrorException.class)
                .build());
    Supplier<Order> fetch =
        Retry.decorateSupplier(
            retry, () -> client.get().uri("/v1/orders/order_1").retrieve().body(Order.class));

    Order order = fetch.get();

    assertThat(order.status()).isEqualTo("paid");
    vendor.verify(3, getRequestedFor(urlPathEqualTo("/v1/orders/order_1")));
  }

  record CreateOrder(long amount, String currency) {}

  record Order(String id, long amount, String status) {}
}
