package in.proxycare.shared.config;

import java.util.Arrays;
import java.util.Optional;

/** Where the application runs. Each value has exactly one Spring profile. */
public enum DeploymentEnvironment {
  LOCAL("local"),
  TEST("test"),
  STAGING("staging"),
  PRODUCTION("prod");

  private final String profile;

  DeploymentEnvironment(String profile) {
    this.profile = profile;
  }

  /** The Spring profile that selects this environment. */
  public String profile() {
    return profile;
  }

  /** Whether this environment serves real users or holds real data. */
  public boolean isDeployed() {
    return this == STAGING || this == PRODUCTION;
  }

  /** The environment selected by {@code profile}, if it is a deployment profile. */
  public static Optional<DeploymentEnvironment> forProfile(String profile) {
    return Arrays.stream(values()).filter(env -> env.profile.equals(profile)).findFirst();
  }
}
