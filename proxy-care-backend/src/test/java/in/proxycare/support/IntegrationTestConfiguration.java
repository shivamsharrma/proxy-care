package in.proxycare.support;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;

/** Everything {@link IntegrationTest} adds to the application context. */
@TestConfiguration(proxyBeanMethods = false)
@Import({PostgresTestcontainersConfiguration.class, ClockTestConfiguration.class})
class IntegrationTestConfiguration {

  @Bean
  AdminDatabase adminDatabase() {
    return new AdminDatabase();
  }

  /** Cleans as the superuser: the application role may not TRUNCATE, by design. */
  @Bean
  DatabaseCleaner databaseCleaner(AdminDatabase admin) {
    return new DatabaseCleaner(admin.client());
  }
}
