package in.proxycare.shared.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import in.proxycare.support.Concurrently;
import in.proxycare.support.Concurrently.Outcome;
import in.proxycare.support.IntegrationTest;
import in.proxycare.support.MutableClock;
import in.proxycare.support.TestIds;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;

/**
 * Example concurrency test. Eight threads race through the two database patterns ADR 0007 relies
 * on; the assertions hold for every possible interleaving, so the test is deterministic without any
 * sleep.
 */
@IntegrationTest
class ConcurrentWritesTest {

  private static final int THREADS = 8;

  @Autowired private JdbcClient jdbc;
  @Autowired private MutableClock clock;

  @Test
  void insertIfAbsentCreatesExactlyOneRow() {
    AtomicInteger ids = new AtomicInteger();

    List<Outcome<Integer>> outcomes =
        Concurrently.run(
            THREADS,
            () ->
                jdbc.sql(
                        "insert into proxycare.test_probe"
                            + " (id, natural_key, amount_paise, created_at)"
                            + " values (:id, 'same-request', 100, :createdAt)"
                            + " on conflict (natural_key) do nothing")
                    .param("id", TestIds.uuid(9, ids.incrementAndGet()))
                    .param("createdAt", clock.instant().atOffset(ZoneOffset.UTC))
                    .update());

    assertThat(outcomes).allMatch(Outcome::succeeded);
    assertThat(outcomes).extracting(Outcome::value).containsOnlyOnce(1);
    assertThat(jdbc.sql("select count(*) from proxycare.test_probe").query(Long.class).single())
        .isOne();
  }

  @Test
  void conditionalUpdateHasExactlyOneWinner() {
    UUID id = TestIds.uuid(9, 1);
    jdbc.sql(
            "insert into proxycare.test_probe (id, natural_key, amount_paise, created_at)"
                + " values (:id, 'claimable', 100, :createdAt)")
        .param("id", id)
        .param("createdAt", clock.instant().atOffset(ZoneOffset.UTC))
        .update();

    List<Outcome<Integer>> outcomes =
        Concurrently.run(
            THREADS,
            () ->
                jdbc.sql(
                        "update proxycare.test_probe set state = 'CLAIMED'"
                            + " where id = :id and state = 'OPEN'")
                    .param("id", id)
                    .update());

    assertThat(outcomes).allMatch(Outcome::succeeded);
    assertThat(outcomes).extracting(Outcome::value).containsOnlyOnce(1);
    assertThat(outcomes).extracting(Outcome::value).filteredOn(rows -> rows == 0).hasSize(7);
  }
}
