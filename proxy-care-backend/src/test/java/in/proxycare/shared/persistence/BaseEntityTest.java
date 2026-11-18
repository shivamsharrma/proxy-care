package in.proxycare.shared.persistence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import in.proxycare.shared.money.Money;
import in.proxycare.support.AdminDatabase;
import in.proxycare.support.IntegrationTest;
import in.proxycare.support.MutableClock;
import in.proxycare.support.persistence.ProbeEntity;
import in.proxycare.support.persistence.ProbeEntityRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.stream.IntStream;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.transaction.support.TransactionTemplate;

/** BaseEntity's behaviour through real JPA, Hibernate and PostgreSQL. */
@IntegrationTest
class BaseEntityTest {

  @Autowired private ProbeEntityRepository repository;
  @Autowired private TransactionTemplate transactions;
  @Autowired private MutableClock clock;
  @Autowired private AdminDatabase admin;

  @Test
  void auditsCreationAndUpdatesWithTheApplicationClock() {
    Instant created = clock.instant();
    ProbeEntity saved = repository.save(new ProbeEntity("first", Money.ofRupees(100)));

    assertThat(saved.getCreatedAt()).isEqualTo(created);
    assertThat(saved.getUpdatedAt()).isEqualTo(created);

    clock.advance(Duration.ofMinutes(5));
    transactions.executeWithoutResult(
        status -> repository.findById(saved.getId()).orElseThrow().rename("second"));

    ProbeEntity updated = repository.findById(saved.getId()).orElseThrow();
    assertThat(updated.getCreatedAt()).isEqualTo(created);
    assertThat(updated.getUpdatedAt()).isEqualTo(created.plus(Duration.ofMinutes(5)));
  }

  @Test
  void storesAuditTimestampsWithoutLosingPrecision() {
    // The real clock has nanoseconds; PostgreSQL keeps microseconds. Auditing truncates first, so
    // what the entity holds is exactly what the database returns.
    clock.setTo(Instant.parse("2026-01-15T09:00:00.123456789Z"));

    UUID id = repository.save(new ProbeEntity("precise", Money.ZERO)).getId();

    Instant stored = repository.findById(id).orElseThrow().getCreatedAt();
    assertThat(stored).isEqualTo(Instant.parse("2026-01-15T09:00:00.123456Z"));
  }

  @Test
  void assignsTimeOrderedVersion7Ids() {
    long before = System.currentTimeMillis();

    List<UUID> ids =
        IntStream.range(0, 50)
            .mapToObj(i -> repository.save(new ProbeEntity("e" + i, Money.ZERO)).getId())
            .toList();

    long after = System.currentTimeMillis();
    assertThat(ids)
        .doesNotHaveDuplicates()
        .allSatisfy(id -> {
          assertThat(id.version()).isEqualTo(7);
          assertThat(id.variant()).isEqualTo(2); // RFC 9562 variant
          // The first 48 bits are the Unix time in milliseconds when the id was generated.
          assertThat(id.getMostSignificantBits() >>> 16).isBetween(before, after);
        });
  }

  @Test
  void countsVersionsFromZero() {
    ProbeEntity saved = repository.save(new ProbeEntity("v", Money.ZERO));
    assertThat(saved.getVersion()).isZero();

    transactions.executeWithoutResult(
        status -> repository.findById(saved.getId()).orElseThrow().rename("v2"));

    assertThat(repository.findById(saved.getId()).orElseThrow().getVersion()).isOne();
  }

  @Test
  void rejectsAnUpdateBasedOnAStaleVersion() {
    UUID id = repository.save(new ProbeEntity("original", Money.ZERO)).getId();
    ProbeEntity staleCopy = repository.findById(id).orElseThrow();

    // Someone else updates the row first.
    transactions.executeWithoutResult(
        status -> repository.findById(id).orElseThrow().rename("changed elsewhere"));

    staleCopy.rename("lost update");
    assertThatThrownBy(() -> repository.save(staleCopy))
        .isInstanceOf(ObjectOptimisticLockingFailureException.class);
    assertThat(repository.findById(id).orElseThrow().getName()).isEqualTo("changed elsewhere");
  }

  @Test
  void storesMoneyAsPaise() {
    UUID id = repository.save(new ProbeEntity("priced", Money.ofPaise(124_950))).getId();

    assertThat(repository.findById(id).orElseThrow().getAmount()).isEqualTo(Money.ofPaise(124_950));
    assertThat(
            admin
                .client()
                .sql("select amount_paise from proxycare.test_probe_entity where id = :id")
                .param("id", id)
                .query(Long.class)
                .single())
        .isEqualTo(124_950L);
  }

  @Test
  void softDeleteHidesTheRowButKeepsIt() {
    UUID id = repository.save(new ProbeEntity("to delete", Money.ZERO)).getId();

    repository.deleteById(id);

    assertThat(repository.findById(id)).isEmpty();
    assertThat(repository.count()).isZero();
    assertThat(
            admin
                .client()
                .sql("select deleted from proxycare.test_probe_entity where id = :id")
                .param("id", id)
                .query(Boolean.class)
                .single())
        .isTrue();
  }

  @Test
  void isEqualByIdOnceSaved() {
    ProbeEntity unsaved = new ProbeEntity("a", Money.ZERO);
    assertThat(unsaved).isEqualTo(unsaved).isNotEqualTo(new ProbeEntity("a", Money.ZERO));

    UUID id = repository.save(unsaved).getId();

    assertThat(repository.findById(id).orElseThrow())
        .isEqualTo(repository.findById(id).orElseThrow())
        .hasSameHashCodeAs(unsaved);
  }
}
