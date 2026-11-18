package in.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;

import in.proxycare.support.Concurrently.Outcome;
import java.util.List;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

class ConcurrentlyTest {

  @Test
  void runsEveryActionAtTheSameTime() {
    // The barrier only opens when all four threads are inside the action at once; if they ran
    // one after another, await would time out and every outcome would be a failure.
    CyclicBarrier allInside = new CyclicBarrier(4);

    List<Outcome<Integer>> outcomes =
        Concurrently.run(4, () -> allInside.await(10, TimeUnit.SECONDS));

    assertThat(outcomes).hasSize(4).allMatch(Outcome::succeeded);
  }

  @Test
  void reportsFailuresWithoutHidingSuccesses() {
    AtomicInteger calls = new AtomicInteger();

    List<Outcome<Integer>> outcomes =
        Concurrently.run(
            3,
            () -> {
              if (calls.incrementAndGet() == 2) {
                throw new IllegalStateException("second caller lost");
              }
              return 1;
            });

    assertThat(outcomes).filteredOn(Outcome::succeeded).hasSize(2);
    assertThat(outcomes)
        .filteredOn(outcome -> !outcome.succeeded())
        .singleElement()
        .extracting(Outcome::failure)
        .isInstanceOf(IllegalStateException.class);
  }

  @Test
  void needsAtLeastTwoThreads() {
    assertThatIllegalArgumentException().isThrownBy(() -> Concurrently.run(1, () -> 1));
  }
}
