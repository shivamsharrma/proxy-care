package in.proxycare.shared.config;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Application-wide settings under {@code proxycare.*}. Feature-specific settings get their own
 * records in their modules.
 *
 * @param environment the deployment environment; set by each profile's configuration file
 * @param jobs scheduled-job settings
 */
@Validated
@ConfigurationProperties("proxycare")
public record ProxyCareProperties(
    @NotNull DeploymentEnvironment environment, @NotNull @Valid Jobs jobs) {

  /**
   * @param enabled whether {@code @Scheduled} jobs run in this process
   */
  public record Jobs(boolean enabled) {}
}
