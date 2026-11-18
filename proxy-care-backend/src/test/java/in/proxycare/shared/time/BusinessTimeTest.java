package in.proxycare.shared.time;

import static org.assertj.core.api.Assertions.assertThat;

import in.proxycare.support.MutableClock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import org.junit.jupiter.api.Test;

class BusinessTimeTest {

  private final MutableClock clock = new MutableClock();
  private final BusinessTime businessTime = new BusinessTime(clock);

  @Test
  void usesIndiaStandardTime() {
    assertThat(BusinessTime.ZONE).isEqualTo(ZoneId.of("Asia/Kolkata"));
  }

  @Test
  void readsTheInjectedClock() {
    assertThat(businessTime.now()).isEqualTo(MutableClock.DEFAULT_INSTANT);
  }

  @Test
  void todayChangesAtIndianMidnightNotUtcMidnight() {
    // 18:29:59 UTC is 23:59:59 IST; one second later it is the next day in India.
    clock.setTo(Instant.parse("2026-11-01T18:29:59Z"));
    assertThat(businessTime.today()).isEqualTo(LocalDate.of(2026, 11, 1));

    clock.setTo(Instant.parse("2026-11-01T18:30:00Z"));
    assertThat(businessTime.today()).isEqualTo(LocalDate.of(2026, 11, 2));
  }

  @Test
  void convertsAPickupWallClockTimeToAUtcInstant() {
    // The design document's example: pickup Monday 2 November, 10:00 AM in India.
    Instant pickup = businessTime.toInstant(LocalDate.of(2026, 11, 2), LocalTime.of(10, 0));

    assertThat(pickup).isEqualTo(Instant.parse("2026-11-02T04:30:00Z"));
  }

  @Test
  void showsAStoredInstantInIndianTime() {
    var local = businessTime.inBusinessZone(Instant.parse("2026-11-02T04:30:00Z"));

    assertThat(local.toLocalDate()).isEqualTo(LocalDate.of(2026, 11, 2));
    assertThat(local.toLocalTime()).isEqualTo(LocalTime.of(10, 0));
  }

  @Test
  void startsADayAtIndianMidnight() {
    assertThat(businessTime.startOfDay(LocalDate.of(2026, 11, 2)))
        .isEqualTo(Instant.parse("2026-11-01T18:30:00Z"));
  }
}
