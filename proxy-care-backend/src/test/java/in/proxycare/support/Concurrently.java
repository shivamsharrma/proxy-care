package in.proxycare.support;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/**
 * Runs the same action on several threads released at the same moment, to provoke races.
 *
 * <p>Tests assert on the outcomes, never on timing: "exactly one of eight inserts succeeded" is
 * true however the threads interleave. No sleeps; the only waits are latches and bounded future
 * gets.
 *
 * <pre>{@code
 * List<Outcome<Integer>> outcomes = Concurrently.run(8, () -> repository.claim(key));
 * assertThat(outcomes).filteredOn(o -> o.value() == 1).hasSize(1);
 * }</pre>
 */
public final class Concurrently {

  /** Upper bound for a whole run; reaching it fails the test instead of hanging the build. */
  public static final Duration TIMEOUT = Duration.ofSeconds(30);

  private Concurrently() {}

  public static <T> List<Outcome<T>> run(int threads, Callable<T> action) {
    if (threads < 2) {
      throw new IllegalArgumentException("a race needs at least two threads");
    }
    CountDownLatch ready = new CountDownLatch(threads);
    CountDownLatch start = new CountDownLatch(1);
    // Platform threads: one real thread per participant, so they genuinely run in parallel.
    try (ExecutorService executor = Executors.newFixedThreadPool(threads)) {
      List<Future<T>> futures = new ArrayList<>(threads);
      for (int i = 0; i < threads; i++) {
        futures.add(
            executor.submit(() -> {
              ready.countDown();
              start.await();
              return action.call();
            }));
      }
      await(ready);
      start.countDown();
      List<Outcome<T>> outcomes = new ArrayList<>(threads);
      for (Future<T> future : futures) {
        outcomes.add(collect(future));
      }
      return outcomes;
    }
  }

  private static void await(CountDownLatch latch) {
    try {
      if (!latch.await(TIMEOUT.toMillis(), TimeUnit.MILLISECONDS)) {
        throw new IllegalStateException("Threads did not reach the start line within " + TIMEOUT);
      }
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new IllegalStateException("Interrupted while waiting for threads", e);
    }
  }

  private static <T> Outcome<T> collect(Future<T> future) {
    try {
      return Outcome.success(future.get(TIMEOUT.toMillis(), TimeUnit.MILLISECONDS));
    } catch (ExecutionException e) {
      return Outcome.failure(e.getCause());
    } catch (TimeoutException e) {
      future.cancel(true);
      throw new IllegalStateException("A concurrent action did not finish within " + TIMEOUT, e);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new IllegalStateException("Interrupted while collecting results", e);
    }
  }

  /** What one thread produced: a value or the exception it threw. */
  public record Outcome<T>(T value, Throwable failure) {

    static <T> Outcome<T> success(T value) {
      return new Outcome<>(value, null);
    }

    static <T> Outcome<T> failure(Throwable failure) {
      return new Outcome<>(null, failure);
    }

    public boolean succeeded() {
      return failure == null;
    }
  }
}
