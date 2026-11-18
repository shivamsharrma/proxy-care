package in.proxycare.shared.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;

import java.util.Map;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.logging.LoggingSystem;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

/**
 * Loads the real application-*.yml files for each profile, without auto-configuration, so the
 * profile files and the start-up checks are tested together and no database is needed.
 */
class ProfileConfigurationTest {

  private static final String PASSWORD = "test-only-password-7f3a";

  /**
   * Logging is JVM-wide: without this, starting the staging or prod profile would switch every
   * later test in the run to JSON logs.
   */
  private static final String LOGGING_SYSTEM_PROPERTY = LoggingSystem.SYSTEM_PROPERTY;

  private static String previousLoggingSystem;

  @BeforeAll
  static void leaveLoggingUntouched() {
    previousLoggingSystem = System.setProperty(LOGGING_SYSTEM_PROPERTY, LoggingSystem.NONE);
  }

  @AfterAll
  static void restoreLogging() {
    if (previousLoggingSystem == null) {
      System.clearProperty(LOGGING_SYSTEM_PROPERTY);
    } else {
      System.setProperty(LOGGING_SYSTEM_PROPERTY, previousLoggingSystem);
    }
  }

  private static final Map<String, Object> VALID_DEPLOYED_SETTINGS =
      Map.of(
          "PROXYCARE_DB_URL",
          "jdbc:postgresql://db.example.supabase.co:5432/postgres?sslmode=verify-full",
          "PROXYCARE_DB_USERNAME",
          "proxycare_app",
          "PROXYCARE_DB_PASSWORD",
          PASSWORD);

  @Test
  void localProfileSelectsLocalEnvironmentWithApiDocs() {
    try (var context = start(Map.of(), new String[] {"local"})) {
      Environment env = context.getEnvironment();
      assertThat(env.getProperty("proxycare.environment")).isEqualTo("local");
      assertThat(env.getProperty("springdoc.api-docs.enabled")).isEqualTo("true");
      assertThat(env.getProperty("spring.flyway.enabled")).isEqualTo("true");
    }
  }

  @Test
  void testProfileSelectsTestEnvironment() {
    try (var context = start(Map.of(), new String[] {"test"})) {
      assertThat(context.getEnvironment().getProperty("proxycare.environment")).isEqualTo("test");
    }
  }

  @Test
  void stagingProfileUsesEnvironmentVariablesAndAnInternalManagementPort() {
    try (var context = start(VALID_DEPLOYED_SETTINGS, new String[] {"staging"})) {
      Environment env = context.getEnvironment();
      assertThat(env.getProperty("proxycare.environment")).isEqualTo("staging");
      assertThat(env.getProperty("spring.datasource.username")).isEqualTo("proxycare_app");
      assertThat(env.getProperty("management.server.port")).isEqualTo("8081");
      assertThat(env.getProperty("spring.flyway.enabled")).isEqualTo("false");
      assertThat(env.getProperty("logging.structured.format.console")).isEqualTo("ecs");
    }
  }

  @Test
  void productionProfileDisablesApiDocsAndStartUpMigrations() {
    try (var context = start(VALID_DEPLOYED_SETTINGS, new String[] {"prod"})) {
      Environment env = context.getEnvironment();
      assertThat(env.getProperty("proxycare.environment")).isEqualTo("production");
      assertThat(env.getProperty("springdoc.api-docs.enabled")).isEqualTo("false");
      assertThat(env.getProperty("springdoc.swagger-ui.enabled")).isEqualTo("false");
      assertThat(env.getProperty("spring.flyway.enabled")).isEqualTo("false");
    }
  }

  @Test
  void refusesToStartWithoutADeploymentProfile() {
    assertThat(startupFailure(Map.of(), new String[] {}).violations())
        .singleElement()
        .asString()
        .startsWith("Exactly one deployment profile must be active");
  }

  @Test
  void refusesToStartWithTwoDeploymentProfiles() {
    assertThat(startupFailure(VALID_DEPLOYED_SETTINGS, new String[] {"local", "prod"}).violations())
        .singleElement()
        .asString()
        .contains("[local, prod]");
  }

  @Test
  void productionWithoutDatabaseSettingsFailsFast() {
    assertThat(startupFailure(Map.of(), new String[] {"prod"}).violations())
        .contains(
            "spring.datasource.url is required",
            "spring.datasource.username is required",
            "spring.datasource.password is required");
  }

  @Test
  void productionRejectsALocalDatabaseWithoutLeakingSettings() {
    var settings = withDatabaseUrl("jdbc:postgresql://localhost:5432/postgres?sslmode=verify-full");

    InvalidDeploymentConfigurationException failure =
        startupFailure(settings, new String[] {"prod"});

    assertThat(failure.violations())
        .containsExactly("spring.datasource.url must not point to a local host");
    assertThat(failure.getMessage()).doesNotContain(PASSWORD, "localhost:5432");
  }

  @Test
  void productionRequiresVerifiedTls() {
    var settings = withDatabaseUrl("jdbc:postgresql://db.example.supabase.co:5432/postgres");

    assertThat(startupFailure(settings, new String[] {"prod"}).violations())
        .containsExactly("spring.datasource.url must set sslmode=verify-full");
  }

  @Test
  void productionRejectsAnEnvironmentThatContradictsTheProfile() {
    assertThat(
            startupFailure(
                    VALID_DEPLOYED_SETTINGS, new String[] {"prod"}, "--proxycare.environment=local")
                .violations())
        .containsExactly("proxycare.environment must be PRODUCTION when profile 'prod' is active");
  }

  @Test
  void productionRejectsStartUpMigrationsPublicApiDocsAndASharedManagementPort() {
    assertThat(
            startupFailure(
                    VALID_DEPLOYED_SETTINGS,
                    new String[] {"prod"},
                    "--spring.flyway.enabled=true",
                    "--springdoc.api-docs.enabled=true",
                    "--management.server.port=8080")
                .violations())
        .containsExactlyInAnyOrder(
            "spring.flyway.enabled must be false",
            "springdoc.api-docs.enabled must be false",
            "management.server.port must differ from server.port");
  }

  private static Map<String, Object> withDatabaseUrl(String url) {
    var settings = new java.util.HashMap<>(VALID_DEPLOYED_SETTINGS);
    settings.put("PROXYCARE_DB_URL", url);
    return settings;
  }

  private static ConfigurableApplicationContext start(
      Map<String, Object> defaults, String[] profiles, String... args) {
    return new SpringApplicationBuilder(NoBeans.class)
        .web(WebApplicationType.NONE)
        .profiles(profiles)
        .properties(defaults)
        .logStartupInfo(false)
        .run(args);
  }

  private static InvalidDeploymentConfigurationException startupFailure(
      Map<String, Object> defaults, String[] profiles, String... args) {
    Throwable thrown = catchThrowable(() -> start(defaults, profiles, args).close());
    assertThat(thrown).isInstanceOf(InvalidDeploymentConfigurationException.class);
    return (InvalidDeploymentConfigurationException) thrown;
  }

  @Configuration(proxyBeanMethods = false)
  static class NoBeans {}
}
