package in.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class MutableClockTest {

  private final MutableClock clock = new MutableClock();

  @Test
  void startsAtTheDefaultInstantInUtc() {
    assertThat(clock.instant()).isEqualTo(MutableClock.DEFAULT_INSTANT);
    assertThat(clock.getZone()).isEqualTo(ZoneOffset.UTC);
  }

  @Test
  void standsStillUntilMoved() {
    assertThat(clock.instant()).isEqualTo(clock.instant());
  }

  @Test
  void advancesAndJumps() {
    clock.advance(Duration.ofMinutes(90));
    assertThat(clock.instant()).isEqualTo(Instant.parse("2026-01-15T10:30:00Z"));

    clock.setTo(Instant.parse("2026-11-02T04:30:00Z"));
    assertThat(clock.instant()).isEqualTo(Instant.parse("2026-11-02T04:30:00Z"));
  }

  @Test
  void resetsToTheDefault() {
    clock.advance(Duration.ofDays(3));

    clock.reset();

    assertThat(clock.instant()).isEqualTo(MutableClock.DEFAULT_INSTANT);
  }

  @Test
  void refusesOtherZones() {
    assertThatThrownBy(() -> clock.withZone(ZoneId.of("Asia/Kolkata")))
        .isInstanceOf(UnsupportedOperationException.class);
  }
}
