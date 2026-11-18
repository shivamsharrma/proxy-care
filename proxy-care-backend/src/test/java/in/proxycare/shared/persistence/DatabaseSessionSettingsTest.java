package in.proxycare.shared.persistence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;
import static org.assertj.core.api.Assertions.assertThatIllegalStateException;
import static org.assertj.core.api.Assertions.assertThatNullPointerException;

import com.zaxxer.hikari.HikariDataSource;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.support.StaticListableBeanFactory;

class DatabaseSessionSettingsTest {

  private static final PersistenceProperties SETTINGS =
      new PersistenceProperties(
          Duration.ofSeconds(30), Duration.ofSeconds(10), Duration.ofMinutes(1));

  @Test
  void rendersTheLimitsAsMilliseconds() {
    assertThat(DatabaseSessionSettings.initSql(SETTINGS))
        .isEqualTo(
            "SET statement_timeout = 30000; SET lock_timeout = 10000;"
                + " SET idle_in_transaction_session_timeout = 60000");
  }

  @Test
  void appliesThemToTheConnectionPool() {
    try (HikariDataSource pool = new HikariDataSource()) {
      settings().postProcessBeforeInitialization(pool, "dataSource");

      assertThat(pool.getConnectionInitSql()).isEqualTo(DatabaseSessionSettings.initSql(SETTINGS));
    }
  }

  @Test
  void refusesAConflictingInitStatement() {
    try (HikariDataSource pool = new HikariDataSource()) {
      pool.setConnectionInitSql("SET statement_timeout = 0");

      assertThatIllegalStateException()
          .isThrownBy(() -> settings().postProcessBeforeInitialization(pool, "dataSource"));
    }
  }

  @Test
  void leavesOtherBeansAlone() {
    Object other = new Object();

    assertThat(settings().postProcessBeforeInitialization(other, "other")).isSameAs(other);
  }

  @Test
  void requiresPositiveLimits() {
    // Zero means "no limit" to PostgreSQL, which would silently disable the protection.
    assertThatIllegalArgumentException()
        .isThrownBy(() ->
            new PersistenceProperties(Duration.ZERO, Duration.ofSeconds(1), Duration.ofSeconds(1)))
        .withMessageContaining("statement-timeout");
    assertThatIllegalArgumentException()
        .isThrownBy(() ->
            new PersistenceProperties(
                Duration.ofSeconds(1), Duration.ofSeconds(-1), Duration.ofSeconds(1)))
        .withMessageContaining("lock-timeout");
    assertThatNullPointerException()
        .isThrownBy(
            () -> new PersistenceProperties(Duration.ofSeconds(1), Duration.ofSeconds(1), null))
        .withMessageContaining("idle-in-transaction-session-timeout");
  }

  private static DatabaseSessionSettings settings() {
    StaticListableBeanFactory beans = new StaticListableBeanFactory();
    beans.addBean("persistenceProperties", SETTINGS);
    return new DatabaseSessionSettings(beans.getBeanProvider(PersistenceProperties.class));
  }
}
