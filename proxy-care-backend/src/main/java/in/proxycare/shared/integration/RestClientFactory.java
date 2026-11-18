package in.proxycare.shared.integration;

import java.net.ProxySelector;
import java.net.http.HttpClient;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.http.converter.json.JacksonJsonHttpMessageConverter;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.json.JsonMapper;

/**
 * Builds one {@link RestClient} per vendor over the JDK {@link HttpClient} (ADR 0009).
 *
 * <p>Starts from Spring Boot's {@link RestClient.Builder}, so clients share the application's
 * observation (tracing) setup. The builder is cloned for every client because it is mutable.
 *
 * <p>Vendor responses are read with the application's JSON settings except one: unknown properties
 * are ignored. Our own API rejects unknown input (ADR 0005), but vendors add response fields
 * without notice, and that must not break an integration.
 */
@Component
public class RestClientFactory {

  private final RestClient.Builder applicationBuilder;
  private final JsonMapper vendorJsonMapper;

  public RestClientFactory(
      RestClient.Builder applicationBuilder, JsonMapper applicationJsonMapper) {
    this.applicationBuilder = applicationBuilder;
    this.vendorJsonMapper =
        applicationJsonMapper
            .rebuild()
            .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            .build();
  }

  public RestClient create(HttpClientSettings settings) {
    HttpClient httpClient =
        HttpClient.newBuilder()
            // HTTP/1.1, which every vendor API supports. The JDK default (HTTP/2) negotiates
            // differently over TLS than over plain HTTP, so tests against WireMock would not
            // exercise the protocol production uses.
            .version(HttpClient.Version.HTTP_1_1)
            .connectTimeout(settings.connectTimeout())
            // Explicit: honour the JVM's proxy settings (corporate proxies, the test guard).
            .proxy(ProxySelector.getDefault())
            .followRedirects(HttpClient.Redirect.NEVER)
            .build();
    JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(httpClient);
    requestFactory.setReadTimeout(settings.readTimeout());

    return applicationBuilder
        .clone()
        .baseUrl(settings.baseUrl().toString())
        .requestFactory(requestFactory)
        .configureMessageConverters(converters ->
            converters.withJsonConverter(new JacksonJsonHttpMessageConverter(vendorJsonMapper)))
        .build();
  }
}
