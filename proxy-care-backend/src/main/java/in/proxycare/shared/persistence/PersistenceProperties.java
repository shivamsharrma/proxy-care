package in.proxycare.shared.persistence;

import java.time.Duration;
import java.util.Objects;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Session limits applied to every database connection the application opens (docs/DATABASE.md).
 *
 * @param statementTimeout longest a single statement may run
 * @param lockTimeout longest a statement may wait for a lock
 * @param idleInTransactionSessionTimeout longest a transaction may stay open while idle
 */
@ConfigurationProperties("proxycare.persistence")
public record PersistenceProperties(
    Duration statementTimeout, Duration lockTimeout, Duration idleInTransactionSessionTimeout) {

  public PersistenceProperties {
    requirePositive(statementTimeout, "statement-timeout");
    requirePositive(lockTimeout, "lock-timeout");
    requirePositive(idleInTransactionSessionTimeout, "idle-in-transaction-session-timeout");
  }

  private static void requirePositive(Duration value, String name) {
    Objects.requireNonNull(value, () -> "proxycare.persistence." + name + " is required");
    if (value.isZero() || value.isNegative()) {
      // Zero would mean "no limit" to PostgreSQL.
      throw new IllegalArgumentException("proxycare.persistence." + name + " must be positive");
    }
  }
}
