package in.proxycare.support;

import java.nio.file.Path;
import javax.sql.DataSource;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.context.DynamicPropertyRegistrar;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.utility.MountableFile;

/**
 * The test database: one PostGIS container per test JVM, shared by every Spring test context,
 * prepared exactly like the local and Supabase databases (docs/DATABASE.md).
 *
 * <p>Each party connects with its own role, so tests exercise the real privilege model:
 *
 * <ul>
 *   <li>Flyway as {@code proxycare_migrator}, the schema owner;
 *   <li>the application as {@code proxycare_app}, data access only;
 *   <li>{@link DatabaseCleaner} as the container superuser, which only test code ever uses.
 * </ul>
 *
 * <p>Isolation comes from {@link DatabaseCleaner}, not from a fresh container per class.
 * Testcontainers' Ryuk removes the container when the JVM exits.
 */
@TestConfiguration(proxyBeanMethods = false)
public class PostgresTestcontainersConfiguration {

  /**
   * PostgreSQL 17.5 + PostGIS 3.5.2, pinned by digest. Same image as docker/compose.yaml. The major
   * version must match the Supabase projects (ARCHITECTURE.md, open decision U12).
   */
  static final DockerImageName POSTGIS_IMAGE =
      DockerImageName.parse(
              "postgis/postgis:17-3.5@sha256:01a6a70e41e6c4467c8f55f6063555ed72db2d6662cd0d571040d42eadaeb6f6")
          .asCompatibleSubstituteFor("postgres");

  // Test-only credentials for a throwaway container bound to a random local port.
  private static final String DATABASE = "proxycare_test";
  private static final String ADMIN_USERNAME = "proxycare_admin";
  private static final String ADMIN_PASSWORD = "test-admin";
  static final String APP_USERNAME = "proxycare_app";
  private static final String APP_PASSWORD = "test-app";
  static final String MIGRATOR_USERNAME = "proxycare_migrator";
  private static final String MIGRATOR_PASSWORD = "test-migrator";

  /** Started on first use; shared by every context in the JVM. */
  private static final class Container {
    static final PostgreSQLContainer INSTANCE = start();

    private static PostgreSQLContainer start() {
      PostgreSQLContainer container =
          new PostgreSQLContainer(POSTGIS_IMAGE)
              .withDatabaseName(DATABASE)
              .withUsername(ADMIN_USERNAME)
              .withPassword(ADMIN_PASSWORD)
              .withEnv("PROXYCARE_DB_PASSWORD", APP_PASSWORD)
              .withEnv("PROXYCARE_DB_MIGRATOR_PASSWORD", MIGRATOR_PASSWORD)
              .withEnv("TZ", "UTC")
              .withEnv("PGTZ", "UTC")
              // The same setup files as docker/compose.yaml and production (paths are relative
              // to the project directory, Gradle's test working directory).
              .withCopyFileToContainer(
                  MountableFile.forHostPath(Path.of("database/setup/roles.sql")),
                  "/proxycare-setup/roles.sql")
              .withCopyFileToContainer(
                  MountableFile.forHostPath(Path.of("docker/postgres/init/20-proxycare.sh"), 0755),
                  "/docker-entrypoint-initdb.d/20-proxycare.sh");
      container.start();
      return container;
    }
  }

  @Bean
  DynamicPropertyRegistrar databaseConnections() {
    PostgreSQLContainer container = Container.INSTANCE;
    return registry -> {
      registry.add("spring.datasource.url", container::getJdbcUrl);
      registry.add("spring.datasource.username", () -> APP_USERNAME);
      registry.add("spring.datasource.password", () -> APP_PASSWORD);
      registry.add("spring.flyway.user", () -> MIGRATOR_USERNAME);
      registry.add("spring.flyway.password", () -> MIGRATOR_PASSWORD);
    };
  }

  /** Superuser access for test infrastructure only; never injected into application code. */
  static DataSource adminDataSource() {
    PostgreSQLContainer container = Container.INSTANCE;
    return new DriverManagerDataSource(container.getJdbcUrl(), ADMIN_USERNAME, ADMIN_PASSWORD);
  }
}
