package in.proxycare.shared.persistence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import in.proxycare.support.IntegrationTest;
import in.proxycare.support.MutableClock;
import in.proxycare.support.TestIds;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Example database integration test: real SQL against the real PostGIS image, no mocks.
 *
 * <p>Pins the database behaviour the architecture relies on (ADR 0003): constraints as the last
 * line of defence, transactional rollback, UTC timestamps and PostGIS distance queries. Uses the
 * test-only {@code test_probe} table until feature tables exist.
 */
@IntegrationTest
class PostgresPlatformTest {

  // Bengaluru city centre and a point 0.01 degrees of latitude (about 1.1 km) north of it.
  private static final double LONGITUDE = 77.5946;
  private static final double LATITUDE = 12.9716;

  @Autowired private JdbcClient jdbc;
  @Autowired private TransactionTemplate transactions;
  @Autowired private MutableClock clock;

  @Test
  void enforcesUniqueNaturalKeys() {
    insert(TestIds.uuid(9, 1), "same-key", 100);

    assertThatThrownBy(() -> insert(TestIds.uuid(9, 2), "same-key", 100))
        .isInstanceOf(DuplicateKeyException.class);
  }

  @Test
  void rejectsNegativeMoney() {
    assertThatThrownBy(() -> insert(TestIds.uuid(9, 1), "negative", -1))
        .isInstanceOf(DataIntegrityViolationException.class);
  }

  @Test
  void acceptsZeroMoney() {
    insert(TestIds.uuid(9, 1), "zero", 0);

    assertThat(count()).isOne();
  }

  @Test
  void rollsBackEverythingInAFailedTransaction() {
    transactions.executeWithoutResult(status -> {
      insert(TestIds.uuid(9, 1), "first", 100);
      insert(TestIds.uuid(9, 2), "second", 100);
      status.setRollbackOnly();
    });

    assertThat(count()).isZero();
  }

  @Test
  void storesInstantsInUtcWithoutLoss() {
    Instant now = clock.instant();
    UUID id = TestIds.uuid(9, 1);
    insert(id, "timestamp", 100);

    OffsetDateTime stored =
        jdbc.sql("select created_at from proxycare.test_probe where id = :id")
            .param("id", id)
            .query(OffsetDateTime.class)
            .single();

    assertThat(stored.toInstant()).isEqualTo(now);
    assertThat(stored.getOffset()).isEqualTo(ZoneOffset.UTC);
    assertThat(jdbc.sql("select current_setting('TimeZone')").query(String.class).single())
        .isEqualTo("UTC");
  }

  @Test
  void findsPointsWithinADistanceUsingPostGis() {
    UUID nearby = TestIds.uuid(9, 1);
    insert(nearby, "nearby", 100);
    setLocation(nearby, LONGITUDE, LATITUDE + 0.01);

    assertThat(countWithinMetres(1_500)).isOne();
    assertThat(countWithinMetres(500)).isZero();
  }

  private void insert(UUID id, String naturalKey, long amountPaise) {
    jdbc.sql(
            "insert into proxycare.test_probe (id, natural_key, amount_paise, created_at)"
                + " values (:id, :key, :amount, :createdAt)")
        .param("id", id)
        .param("key", naturalKey)
        .param("amount", amountPaise)
        .param("createdAt", clock.instant().atOffset(ZoneOffset.UTC))
        .update();
  }

  private void setLocation(UUID id, double longitude, double latitude) {
    jdbc.sql(
            "update proxycare.test_probe"
                + " set location = extensions.st_setsrid(extensions.st_makepoint(:lon, :lat), 4326)"
                + " where id = :id")
        .param("lon", longitude)
        .param("lat", latitude)
        .param("id", id)
        .update();
  }

  private long countWithinMetres(int metres) {
    return jdbc.sql(
            "select count(*) from proxycare.test_probe where extensions.st_dwithin(location,"
                + " extensions.st_setsrid(extensions.st_makepoint(:lon, :lat), 4326)::extensions.geography,"
                + " :metres)")
        .param("lon", LONGITUDE)
        .param("lat", LATITUDE)
        .param("metres", metres)
        .query(Long.class)
        .single();
  }

  private long count() {
    return jdbc.sql("select count(*) from proxycare.test_probe").query(Long.class).single();
  }
}
