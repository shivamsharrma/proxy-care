package in.proxycare;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import in.proxycare.shared.config.DeploymentEnvironment;
import in.proxycare.shared.config.ProxyCareProperties;
import in.proxycare.support.IntegrationTest;
import in.proxycare.support.MutableClock;
import in.proxycare.support.TestJson;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import java.time.Clock;
import java.time.Instant;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationContext;
import org.springframework.scheduling.config.TaskManagementConfigUtils;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;

/** The whole application, as tests run it. */
@IntegrationTest
@TestInstance(TestInstance.Lifecycle.PER_CLASS) // mappers() needs the injected context
class ProxyCareApplicationTest {

  @Autowired private ApplicationContext context;
  @Autowired private MockMvcTester mvc;
  @Autowired private Clock clock;

  @Test
  void bindsTheTestEnvironment() {
    ProxyCareProperties properties = context.getBean(ProxyCareProperties.class);

    assertThat(properties.environment()).isEqualTo(DeploymentEnvironment.TEST);
    assertThat(properties.jobs().enabled()).isFalse();
  }

  @Test
  void runsNoScheduledJobs() {
    assertThat(
            context.containsBean(
                TaskManagementConfigUtils.SCHEDULED_ANNOTATION_PROCESSOR_BEAN_NAME))
        .isFalse();
  }

  @Test
  void injectsTheControllableTestClock() {
    assertThat(clock).isInstanceOf(MutableClock.class);
    assertThat(clock.instant()).isEqualTo(MutableClock.DEFAULT_INSTANT);
  }

  @Test
  void reportsLivenessAndReadiness() {
    assertThat(mvc.get().uri("/actuator/health/liveness"))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.status")
        .isEqualTo("UP");
    assertThat(mvc.get().uri("/actuator/health/readiness"))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.status")
        .isEqualTo("UP");
  }

  @Test
  void doesNotCreateADefaultUserWithAGeneratedPassword() {
    assertThat(context.getBeanProvider(UserDetailsService.class).getIfAvailable()).isNull();
  }

  @Test
  void publishesOpenApiDocumentation() {
    assertThat(mvc.get().uri("/v3/api-docs"))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.openapi")
        .asString()
        .startsWith("3.");
  }

  @Test
  void configuresResilience4j() {
    assertThat(context.getBean(CircuitBreakerRegistry.class)).isNotNull();
  }

  /** Both the application's mapper and the TestJson mapper used by unit tests. */
  Stream<JsonMapper> mappers() {
    return Stream.of(context.getBean(JsonMapper.class), TestJson.mapper());
  }

  @ParameterizedTest
  @MethodSource("mappers")
  void writesInstantsAsIsoUtcStrings(JsonMapper mapper) {
    String json =
        mapper.writeValueAsString(new Sample(Instant.parse("2026-11-18T09:30:00Z"), 109_900));

    assertThat(json).isEqualTo("{\"at\":\"2026-11-18T09:30:00Z\",\"amountPaise\":109900}");
  }

  @ParameterizedTest
  @MethodSource("mappers")
  void rejectsUnknownProperties(JsonMapper mapper) {
    String json = "{\"at\":\"2026-11-18T09:30:00Z\",\"amountPaise\":1,\"amountRupees\":1}";

    assertThatThrownBy(() -> mapper.readValue(json, Sample.class))
        .isInstanceOf(JacksonException.class)
        .hasMessageContaining("amountRupees");
  }

  @ParameterizedTest
  @MethodSource("mappers")
  void rejectsFractionalValuesForIntegerAmounts(JsonMapper mapper) {
    String json = "{\"at\":\"2026-11-18T09:30:00Z\",\"amountPaise\":10.5}";

    assertThatThrownBy(() -> mapper.readValue(json, Sample.class))
        .isInstanceOf(JacksonException.class);
  }

  @ParameterizedTest
  @MethodSource("mappers")
  void rejectsMissingPrimitives(JsonMapper mapper) {
    String json = "{\"at\":\"2026-11-18T09:30:00Z\",\"amountPaise\":null}";

    assertThatThrownBy(() -> mapper.readValue(json, Sample.class))
        .isInstanceOf(JacksonException.class);
  }

  record Sample(Instant at, long amountPaise) {}
}
