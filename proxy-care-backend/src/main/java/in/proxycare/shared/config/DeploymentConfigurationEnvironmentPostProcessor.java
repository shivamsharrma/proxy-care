package in.proxycare.shared.config;

import java.util.List;
import org.springframework.boot.EnvironmentPostProcessor;
import org.springframework.boot.SpringApplication;
import org.springframework.core.Ordered;
import org.springframework.core.env.ConfigurableEnvironment;

/**
 * Runs {@link DeploymentConfigurationValidator} once all configuration files and environment
 * variables are loaded, so a misconfigured deployment fails before it opens a connection or a port.
 * Registered in {@code META-INF/spring.factories}.
 */
public final class DeploymentConfigurationEnvironmentPostProcessor
    implements EnvironmentPostProcessor, Ordered {

  private final DeploymentConfigurationValidator validator = new DeploymentConfigurationValidator();

  @Override
  public void postProcessEnvironment(
      ConfigurableEnvironment environment, SpringApplication application) {
    List<String> violations = validator.validate(environment);
    if (!violations.isEmpty()) {
      throw new InvalidDeploymentConfigurationException(violations);
    }
  }

  @Override
  public int getOrder() {
    // After config data (application-*.yml, imports) has been loaded.
    return Ordered.LOWEST_PRECEDENCE;
  }
}
