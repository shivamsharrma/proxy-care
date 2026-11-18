package in.proxycare.shared.jobs;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;

import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.scheduling.config.TaskManagementConfigUtils;

/** Example Awaitility test: waits for an asynchronous effect with a bound, never sleeps. */
class SchedulingConfigurationTest {

  private final ApplicationContextRunner runner =
      new ApplicationContextRunner()
          .withUserConfiguration(SchedulingConfiguration.class, TickingJob.class);

  @Test
  void runsScheduledJobsWhenEnabled() {
    runner
        .withPropertyValues("proxycare.jobs.enabled=true")
        .run(context -> {
          AtomicInteger ticks = context.getBean("ticks", AtomicInteger.class);

          await()
              .atMost(Duration.ofSeconds(10))
              .untilAsserted(() -> assertThat(ticks).hasPositiveValue());
        });
  }

  @Test
  void schedulesNothingWhenDisabled() {
    runner
        .withPropertyValues("proxycare.jobs.enabled=false")
        .run(context ->
            assertThat(context)
                .doesNotHaveBean(
                    TaskManagementConfigUtils.SCHEDULED_ANNOTATION_PROCESSOR_BEAN_NAME));
  }

  @Test
  void schedulesNothingWhenTheSettingIsMissing() {
    runner.run(context ->
        assertThat(context)
            .doesNotHaveBean(TaskManagementConfigUtils.SCHEDULED_ANNOTATION_PROCESSOR_BEAN_NAME));
  }

  @Configuration(proxyBeanMethods = false)
  static class TickingJob {

    private final AtomicInteger ticks = new AtomicInteger();

    @Bean
    AtomicInteger ticks() {
      return ticks;
    }

    @Scheduled(fixedDelay = 10)
    void tick() {
      ticks.incrementAndGet();
    }
  }
}
