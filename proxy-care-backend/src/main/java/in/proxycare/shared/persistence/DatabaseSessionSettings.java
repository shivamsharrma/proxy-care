package in.proxycare.shared.persistence;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.config.BeanPostProcessor;

/**
 * Applies {@link PersistenceProperties} to every new pooled connection through Hikari's
 * connection-init SQL, before the pool opens its first connection.
 *
 * <p>Session settings persist for the life of a connection in direct and session-mode pooled
 * connections; they would not survive transaction-mode pooling, which ADR 0003 rules out. The SQL
 * is built from validated durations in milliseconds, never from raw configuration text.
 */
class DatabaseSessionSettings implements BeanPostProcessor {

  private final ObjectProvider<PersistenceProperties> properties;

  DatabaseSessionSettings(ObjectProvider<PersistenceProperties> properties) {
    this.properties = properties;
  }

  @Override
  public Object postProcessBeforeInitialization(Object bean, String beanName) {
    if (bean instanceof HikariDataSource dataSource) {
      if (dataSource.getConnectionInitSql() != null) {
        throw new IllegalStateException(
            "spring.datasource.hikari.connection-init-sql must not be set; session limits come"
                + " from proxycare.persistence.*");
      }
      dataSource.setConnectionInitSql(initSql(properties.getObject()));
    }
    return bean;
  }

  static String initSql(PersistenceProperties settings) {
    return "SET statement_timeout = "
        + settings.statementTimeout().toMillis()
        + "; SET lock_timeout = "
        + settings.lockTimeout().toMillis()
        + "; SET idle_in_transaction_session_timeout = "
        + settings.idleInTransactionSessionTimeout().toMillis();
  }
}
