package com.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class MutableClockTest {

    private final MutableClock clock = new MutableClock();

    @Test
    void defaultsTo10amIstOnJan15InUtc() {
        assertThat(clock.instant()).isEqualTo(Instant.parse("2026-01-15T04:30:00Z"));
        assertThat(clock.getZone()).isEqualTo(ZoneOffset.UTC);
    }

    @Test
    void advanceMovesTimeForward() {
        clock.advance(Duration.ofMinutes(90));
        assertThat(clock.instant()).isEqualTo(Instant.parse("2026-01-15T06:00:00Z"));
    }

    @Test
    void setReplacesTheInstant() {
        clock.set(Instant.parse("2027-03-01T00:00:00Z"));
        assertThat(clock.instant()).isEqualTo(Instant.parse("2027-03-01T00:00:00Z"));
    }

    @Test
    void resetRestoresTheDefault() {
        clock.advance(Duration.ofDays(3));
        clock.reset();
        assertThat(clock.instant()).isEqualTo(MutableClock.DEFAULT_INSTANT);
    }
}
