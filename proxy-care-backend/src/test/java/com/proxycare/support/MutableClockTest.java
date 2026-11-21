package com.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class MutableClockTest {

    private final MutableClock mutableClock = new MutableClock();

    @Test
    void defaultsTo10amIstOnJan15InUtc() {
        assertThat(mutableClock.instant()).isEqualTo(Instant.parse("2026-01-15T04:30:00Z"));
        assertThat(mutableClock.getZone()).isEqualTo(ZoneOffset.UTC);
    }

    @Test
    void advanceMovesTimeForward() {
        mutableClock.advance(Duration.ofMinutes(90));
        assertThat(mutableClock.instant()).isEqualTo(Instant.parse("2026-01-15T06:00:00Z"));
    }

    @Test
    void setReplacesTheInstant() {
        mutableClock.set(Instant.parse("2027-03-01T00:00:00Z"));
        assertThat(mutableClock.instant()).isEqualTo(Instant.parse("2027-03-01T00:00:00Z"));
    }

    @Test
    void resetRestoresTheDefault() {
        mutableClock.advance(Duration.ofDays(3));
        mutableClock.reset();
        assertThat(mutableClock.instant()).isEqualTo(MutableClock.DEFAULT_INSTANT);
    }
}
