package in.proxycare.shared.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.context.properties.bind.validation.BindValidationException;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;

class ProxyCarePropertiesTest {

  private final ApplicationContextRunner runner =
      new ApplicationContextRunner().withUserConfiguration(PropertiesConfiguration.class);

  @Test
  void bindsEverySetting() {
    runner
        .withPropertyValues("proxycare.environment=production", "proxycare.jobs.enabled=true")
        .run(context -> {
          ProxyCareProperties properties = context.getBean(ProxyCareProperties.class);
          assertThat(properties.environment()).isEqualTo(DeploymentEnvironment.PRODUCTION);
          assertThat(properties.jobs().enabled()).isTrue();
        });
  }

  @Test
  void failsWhenTheEnvironmentIsMissing() {
    runner
        .withPropertyValues("proxycare.jobs.enabled=true")
        .run(context ->
            assertThat(context)
                .hasFailed()
                .getFailure()
                .rootCause()
                .isInstanceOf(BindValidationException.class)
                .hasMessageContaining("environment"));
  }

  @Test
  void failsWhenTheJobsSettingIsMissing() {
    runner
        .withPropertyValues("proxycare.environment=test")
        .run(context ->
            assertThat(context)
                .hasFailed()
                .getFailure()
                .rootCause()
                .isInstanceOf(BindValidationException.class)
                .hasMessageContaining("jobs"));
  }

  @Test
  void failsOnAnUnknownEnvironment() {
    runner
        .withPropertyValues("proxycare.environment=moon")
        .run(context -> assertThat(context).hasFailed());
  }

  @Configuration(proxyBeanMethods = false)
  @EnableConfigurationProperties(ProxyCareProperties.class)
  static class PropertiesConfiguration {}
}
