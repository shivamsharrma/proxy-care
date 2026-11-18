package in.proxycare.support;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/**
 * Replaces the application clock with a {@link MutableClock}. Code that injects {@code
 * java.time.Clock} receives it; tests inject {@code MutableClock} to move time.
 */
@TestConfiguration(proxyBeanMethods = false)
public class ClockTestConfiguration {

  @Bean
  @Primary
  MutableClock testClock() {
    return new MutableClock();
  }
}
