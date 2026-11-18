package in.proxycare.shared.jobs;

import org.springframework.boot.autoconfigure.condition.ConditionalOnBooleanProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Turns on {@code @Scheduled} jobs only when {@code proxycare.jobs.enabled=true}. The test profile
 * leaves it off so no job runs unless a test starts it explicitly.
 */
@Configuration(proxyBeanMethods = false)
@EnableScheduling
@ConditionalOnBooleanProperty("proxycare.jobs.enabled")
class SchedulingConfiguration {}
