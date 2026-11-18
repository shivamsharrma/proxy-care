package in.proxycare.shared.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.env.MockEnvironment;

class DeploymentConfigurationValidatorTest {

  private static final String VALID_URL =
      "jdbc:postgresql://db.example.supabase.co:5432/postgres?sslmode=verify-full";

  private final DeploymentConfigurationValidator validator = new DeploymentConfigurationValidator();

  @Test
  void acceptsAValidProductionConfiguration() {
    assertThat(validator.validate(production())).isEmpty();
  }

  @Test
  void acceptsTheEnvironmentNameInAnyCase() {
    var env = production().withProperty("proxycare.environment", "Production");

    assertThat(validator.validate(env)).isEmpty();
  }

  @Test
  void localNeedsNoDatabaseOrPortSettings() {
    var env = new MockEnvironment().withProperty("proxycare.environment", "local");
    env.setActiveProfiles("local");

    assertThat(validator.validate(env)).isEmpty();
  }

  @Test
  void ignoresNonDeploymentProfiles() {
    var env = production();
    env.setActiveProfiles("prod", "debug-something");

    assertThat(validator.validate(env)).isEmpty();
  }

  @Test
  void requiresTheEnvironmentProperty() {
    var env = new MockEnvironment();
    env.setActiveProfiles("test");

    assertThat(validator.validate(env))
        .containsExactly("proxycare.environment must be TEST when profile 'test' is active");
  }

  @ParameterizedTest
  @ValueSource(
      strings = {
        "jdbc:postgresql://127.0.0.1:5432/postgres?sslmode=verify-full",
        "jdbc:postgresql://LOCALHOST/postgres?sslmode=verify-full",
        "jdbc:postgresql://[::1]:5432/postgres?sslmode=verify-full"
      })
  void rejectsLocalDatabaseHosts(String url) {
    var env = production().withProperty("spring.datasource.url", url);

    assertThat(validator.validate(env))
        .containsExactly("spring.datasource.url must not point to a local host");
  }

  @ParameterizedTest
  @ValueSource(
      strings = {
        "jdbc:postgresql://db.example.supabase.co/postgres?sslmode=require",
        "jdbc:postgresql://db.example.supabase.co/postgres?sslmode=verify-ca",
        "jdbc:postgresql://db.example.supabase.co/postgres?xsslmode=verify-full"
      })
  void rejectsTlsWithoutHostVerification(String url) {
    var env = production().withProperty("spring.datasource.url", url);

    assertThat(validator.validate(env))
        .containsExactly("spring.datasource.url must set sslmode=verify-full");
  }

  @Test
  void acceptsVerifyFullAmongOtherParameters() {
    var env =
        production()
            .withProperty(
                "spring.datasource.url",
                "jdbc:postgresql://db.example.supabase.co:5432/postgres?ApplicationName=x"
                    + "&sslmode=verify-full&sslrootcert=/etc/ssl/supabase.crt");

    assertThat(validator.validate(env)).isEmpty();
  }

  @ParameterizedTest
  @ValueSource(strings = {"jdbc:mysql://db.example.com/x", "postgres://db.example.com/x", "jdbc:"})
  void rejectsNonPostgresUrls(String url) {
    var env = production().withProperty("spring.datasource.url", url);

    assertThat(validator.validate(env))
        .containsExactly("spring.datasource.url must be a jdbc:postgresql:// URL");
  }

  @Test
  void reportsUnresolvablePlaceholdersByNameOnly() {
    var env = production().withProperty("spring.datasource.password", "${NOT_SET_ANYWHERE}");

    assertThat(validator.validate(env))
        .containsExactly("spring.datasource.password has an unresolvable placeholder");
  }

  @Test
  void stagingMayPublishApiDocsButNotRunMigrationsAtStartUp() {
    var env =
        production()
            .withProperty("proxycare.environment", "staging")
            .withProperty("springdoc.api-docs.enabled", "true")
            .withProperty("spring.flyway.enabled", "true");
    env.setActiveProfiles("staging");

    assertThat(validator.validate(env)).containsExactly("spring.flyway.enabled must be false");
  }

  @Test
  void requiresAManagementPort() {
    assertThat(validator.validate(production("management.server.port")))
        .containsExactly("management.server.port is required");
  }

  @Test
  void treatsAMissingFlagAsNotDisabled() {
    assertThat(validator.validate(production("springdoc.swagger-ui.enabled")))
        .containsExactly("springdoc.swagger-ui.enabled must be false");
  }

  @Test
  void rejectsTheTransactionModePooler() {
    var env =
        production()
            .withProperty(
                "spring.datasource.url",
                "jdbc:postgresql://aws-0-ap-south-1.pooler.supabase.com:6543/postgres?sslmode=verify-full");

    assertThat(validator.validate(env))
        .containsExactly(
            "spring.datasource.url must not use the transaction-mode pooler (port 6543); use a"
                + " direct or session-mode connection");
  }

  @Test
  void acceptsTheSessionModePooler() {
    var env =
        production()
            .withProperty(
                "spring.datasource.url",
                "jdbc:postgresql://aws-0-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=verify-full");

    assertThat(validator.validate(env)).isEmpty();
  }

  @ParameterizedTest
  @ValueSource(strings = {"create", "create-drop", "update", "UPDATE"})
  void rejectsHibernateSchemaGenerationInEveryEnvironment(String value) {
    var local = new MockEnvironment().withProperty("proxycare.environment", "local");
    local.setActiveProfiles("local");
    local.setProperty("spring.jpa.hibernate.ddl-auto", value);
    var prod = production().withProperty("spring.jpa.properties.hibernate.hbm2ddl.auto", value);

    assertThat(validator.validate(local))
        .containsExactly(
            "spring.jpa.hibernate.ddl-auto must be validate or none (Flyway owns the schema)");
    assertThat(validator.validate(prod))
        .containsExactly(
            "spring.jpa.properties.hibernate.hbm2ddl.auto must be validate or none (Flyway owns the"
                + " schema)");
  }

  @ParameterizedTest
  @ValueSource(strings = {"validate", "none"})
  void allowsSchemaValidationOrNothing(String value) {
    var env = production().withProperty("spring.jpa.hibernate.ddl-auto", value);

    assertThat(validator.validate(env)).isEmpty();
  }

  /** A valid production configuration, minus the {@code omitted} properties. */
  private static MockEnvironment production(String... omitted) {
    Map<String, String> settings = new LinkedHashMap<>();
    settings.put("proxycare.environment", "production");
    settings.put("spring.datasource.url", VALID_URL);
    settings.put("spring.datasource.username", "proxycare_app");
    settings.put("spring.datasource.password", "not-a-real-secret");
    settings.put("server.port", "8080");
    settings.put("management.server.port", "8081");
    settings.put("spring.flyway.enabled", "false");
    settings.put("springdoc.api-docs.enabled", "false");
    settings.put("springdoc.swagger-ui.enabled", "false");
    List.of(omitted).forEach(settings::remove);

    var env = new MockEnvironment();
    settings.forEach(env::setProperty);
    env.setActiveProfiles("prod");
    return env;
  }
}
