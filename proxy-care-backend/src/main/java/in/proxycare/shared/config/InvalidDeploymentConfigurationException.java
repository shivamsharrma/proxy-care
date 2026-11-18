package in.proxycare.shared.config;

import java.util.ArrayList;
import java.util.List;

/** The configuration breaks a mandatory deployment rule; the application must not start. */
public final class InvalidDeploymentConfigurationException extends RuntimeException {

  private static final long serialVersionUID = 1L;

  /** Property-level problems; each names a property, never its value. */
  private final ArrayList<String> violations;

  InvalidDeploymentConfigurationException(List<String> violations) {
    super("Invalid deployment configuration:\n - " + String.join("\n - ", violations));
    this.violations = new ArrayList<>(violations);
  }

  public List<String> violations() {
    return List.copyOf(violations);
  }
}
