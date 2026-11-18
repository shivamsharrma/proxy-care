package in.proxycare.shared.config;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import org.springframework.core.env.ConfigurableEnvironment;

/**
 * Checks the configuration rules that the architecture decisions make mandatory, before any bean is
 * created.
 *
 * <p>Violations name the offending property but never its value: a datasource URL or password must
 * not end up in a startup log.
 *
 * <ul>
 *   <li>Exactly one deployment profile is active and {@code proxycare.environment} matches it.
 *   <li>Every environment: Hibernate never creates or alters the schema (Flyway owns it).
 *   <li>Staging and production: database settings are present, TLS is verified, the database is not
 *       local and is not reached through the transaction-mode pooler, Flyway does not run at
 *       start-up (ADR 0003) and actuator is on its own port (ADR 0006).
 *   <li>Production: API documentation is disabled (ADR 0005).
 * </ul>
 */
final class DeploymentConfigurationValidator {

  static final String ENVIRONMENT_PROPERTY = "proxycare.environment";

  private static final List<String> REQUIRED_DATABASE_PROPERTIES =
      List.of("spring.datasource.url", "spring.datasource.username", "spring.datasource.password");

  private static final Set<String> LOCAL_HOSTS = Set.of("localhost", "127.0.0.1", "[::1]", "::1");

  /** Supabase's transaction-mode pooler port (shared Supavisor and dedicated PgBouncer). */
  private static final int TRANSACTION_POOLER_PORT = 6543;

  /** Both ways of setting Hibernate's schema tool; only these values are allowed. */
  private static final List<String> SCHEMA_GENERATION_PROPERTIES =
      List.of("spring.jpa.hibernate.ddl-auto", "spring.jpa.properties.hibernate.hbm2ddl.auto");

  private static final Set<String> ALLOWED_SCHEMA_GENERATION = Set.of("validate", "none");

  List<String> validate(ConfigurableEnvironment environment) {
    List<DeploymentEnvironment> selected =
        Arrays.stream(environment.getActiveProfiles())
            .map(DeploymentEnvironment::forProfile)
            .flatMap(Optional::stream)
            .distinct()
            .toList();
    if (selected.size() != 1) {
      return List.of(
          "Exactly one deployment profile must be active (local, test, staging or prod); found "
              + selected.stream().map(DeploymentEnvironment::profile).toList());
    }
    DeploymentEnvironment deployment = selected.getFirst();

    List<String> violations = new ArrayList<>();
    checkEnvironmentMatchesProfile(environment, deployment, violations);
    checkNoSchemaGeneration(environment, violations);
    if (deployment.isDeployed()) {
      checkDatabase(environment, violations);
      checkManagementPort(environment, violations);
      requireFalse(environment, "spring.flyway.enabled", violations);
    }
    if (deployment == DeploymentEnvironment.PRODUCTION) {
      requireFalse(environment, "springdoc.api-docs.enabled", violations);
      requireFalse(environment, "springdoc.swagger-ui.enabled", violations);
    }
    return List.copyOf(violations);
  }

  private static void checkEnvironmentMatchesProfile(
      ConfigurableEnvironment environment,
      DeploymentEnvironment deployment,
      List<String> violations) {
    String configured = property(environment, ENVIRONMENT_PROPERTY, violations);
    // A present but unresolvable value has already been reported by property().
    boolean mismatch =
        configured == null
            ? !environment.containsProperty(ENVIRONMENT_PROPERTY)
            : !deployment.name().equals(configured.trim().toUpperCase(Locale.ROOT));
    if (mismatch) {
      violations.add(
          ENVIRONMENT_PROPERTY
              + " must be "
              + deployment
              + " when profile '"
              + deployment.profile()
              + "' is active");
    }
  }

  private static void checkNoSchemaGeneration(
      ConfigurableEnvironment environment, List<String> violations) {
    for (String name : SCHEMA_GENERATION_PROPERTIES) {
      String value = property(environment, name, violations);
      if (value != null
          && !ALLOWED_SCHEMA_GENERATION.contains(value.trim().toLowerCase(Locale.ROOT))) {
        violations.add(name + " must be validate or none (Flyway owns the schema)");
      }
    }
  }

  private static void checkDatabase(ConfigurableEnvironment environment, List<String> violations) {
    for (String name : REQUIRED_DATABASE_PROPERTIES) {
      String value = property(environment, name, violations);
      if (value != null && value.isBlank()) {
        violations.add(name + " is required");
      }
    }
    String url = property(environment, "spring.datasource.url", violations);
    if (url == null || url.isBlank()) {
      return;
    }
    Optional<URI> uri = parseJdbcUrl(url);
    if (uri.isEmpty()) {
      violations.add("spring.datasource.url must be a jdbc:postgresql:// URL");
      return;
    }
    String host = uri.get().getHost();
    if (host == null || LOCAL_HOSTS.contains(host.toLowerCase(Locale.ROOT))) {
      violations.add("spring.datasource.url must not point to a local host");
    }
    if (!hasQueryParameter(uri.get(), "sslmode", "verify-full")) {
      violations.add("spring.datasource.url must set sslmode=verify-full");
    }
    if (uri.get().getPort() == TRANSACTION_POOLER_PORT) {
      violations.add(
          "spring.datasource.url must not use the transaction-mode pooler (port 6543); use a"
              + " direct or session-mode connection");
    }
  }

  private static void checkManagementPort(
      ConfigurableEnvironment environment, List<String> violations) {
    String managementPort = property(environment, "management.server.port", violations);
    String serverPort = property(environment, "server.port", violations);
    if (managementPort == null || managementPort.isBlank()) {
      violations.add("management.server.port is required");
    } else if (Objects.equals(
        managementPort.trim(), serverPort == null ? null : serverPort.trim())) {
      violations.add("management.server.port must differ from server.port");
    }
  }

  private static void requireFalse(
      ConfigurableEnvironment environment, String name, List<String> violations) {
    String value = property(environment, name, violations);
    if (value == null || !value.trim().equalsIgnoreCase("false")) {
      violations.add(name + " must be false");
    }
  }

  /** The resolved value, or null when absent or when a placeholder cannot be resolved. */
  private static String property(
      ConfigurableEnvironment environment, String name, List<String> violations) {
    try {
      return environment.getProperty(name);
    } catch (IllegalArgumentException unresolvablePlaceholder) {
      violations.add(name + " has an unresolvable placeholder");
      return null;
    }
  }

  private static Optional<URI> parseJdbcUrl(String url) {
    String prefix = "jdbc:postgresql://";
    if (!url.startsWith(prefix)) {
      return Optional.empty();
    }
    try {
      return Optional.of(new URI(url.substring("jdbc:".length())));
    } catch (URISyntaxException malformed) {
      return Optional.empty();
    }
  }

  private static boolean hasQueryParameter(URI uri, String name, String expected) {
    String query = uri.getRawQuery();
    if (query == null) {
      return false;
    }
    return Arrays.stream(query.split("&"))
        .map(pair -> pair.split("=", 2))
        .anyMatch(pair -> pair.length == 2 && pair[0].equals(name) && pair[1].equals(expected));
  }
}
