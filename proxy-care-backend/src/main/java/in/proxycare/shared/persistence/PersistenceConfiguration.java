package in.proxycare.shared.persistence;

import java.time.Clock;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.auditing.DateTimeProvider;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/** Connection session limits and JPA auditing driven by the injected {@link Clock}. */
@Configuration(proxyBeanMethods = false)
@EnableJpaAuditing(dateTimeProviderRef = "auditingDateTimeProvider")
class PersistenceConfiguration {

  /** Static: post-processors are created before other beans. */
  @Bean
  static BeanPostProcessor databaseSessionSettings(
      ObjectProvider<PersistenceProperties> properties) {
    return new DatabaseSessionSettings(properties);
  }

  /**
   * Audit timestamps come from the application clock, truncated to microseconds: PostgreSQL's
   * {@code timestamptz} precision, so the value in memory equals the value stored.
   */
  @Bean
  DateTimeProvider auditingDateTimeProvider(Clock clock) {
    return () -> Optional.of(clock.instant().truncatedTo(ChronoUnit.MICROS));
  }
}
