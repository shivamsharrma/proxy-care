package com.proxycare.config.persistence;

import java.time.Clock;
import java.time.ZonedDateTime;
import java.util.Optional;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.auditing.DateTimeProvider;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/** JPA auditing: {@code @CreatedDate} and {@code @LastModifiedDate} are ZonedDateTime values read from the Clock. */
@Configuration(proxyBeanMethods = false)
@EnableJpaAuditing(dateTimeProviderRef = JpaAuditingConfig.DATE_TIME_PROVIDER)
public class JpaAuditingConfig {

    static final String DATE_TIME_PROVIDER = "auditingDateTimeProvider";

    @Bean(DATE_TIME_PROVIDER)
    DateTimeProvider auditingDateTimeProvider(Clock clock) {
        return () -> Optional.of(ZonedDateTime.now(clock));
    }
}
