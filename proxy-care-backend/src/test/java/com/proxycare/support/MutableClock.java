package com.proxycare.support;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;

/** A fixed clock tests can move. Integration tests reset it before every test. */
public class MutableClock extends Clock {

    /** 2026-01-15 10:00 IST. */
    public static final Instant DEFAULT_INSTANT = Instant.parse("2026-01-15T04:30:00Z");

    private volatile Instant now = DEFAULT_INSTANT;

    public void set(Instant instant) {
        now = instant;
    }

    public void advance(Duration duration) {
        now = now.plus(duration);
    }

    public void reset() {
        now = DEFAULT_INSTANT;
    }

    @Override
    public Instant instant() {
        return now;
    }

    @Override
    public ZoneId getZone() {
        return ZoneOffset.UTC;
    }

    @Override
    public Clock withZone(ZoneId zone) {
        throw new UnsupportedOperationException("MutableClock is always UTC");
    }
}
