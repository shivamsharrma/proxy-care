package in.proxycare.support;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicReference;

/**
 * A UTC clock that stands still until a test moves it. Replaces the application {@link Clock} in
 * integration tests ({@link ClockTestConfiguration}) and is reset to {@link #DEFAULT_INSTANT}
 * before each test.
 */
public final class MutableClock extends Clock {

  /** Where every test starts. Arbitrary but fixed. */
  public static final Instant DEFAULT_INSTANT = Instant.parse("2026-01-15T09:00:00Z");

  private final AtomicReference<Instant> now;

  public MutableClock() {
    this(DEFAULT_INSTANT);
  }

  public MutableClock(Instant start) {
    this.now = new AtomicReference<>(Objects.requireNonNull(start, "start"));
  }

  public void setTo(Instant instant) {
    now.set(Objects.requireNonNull(instant, "instant"));
  }

  public void advance(Duration duration) {
    Objects.requireNonNull(duration, "duration");
    now.updateAndGet(current -> current.plus(duration));
  }

  public void reset() {
    now.set(DEFAULT_INSTANT);
  }

  @Override
  public Instant instant() {
    return now.get();
  }

  @Override
  public ZoneId getZone() {
    return ZoneOffset.UTC;
  }

  /** Always UTC: the application never works in another zone (ADR 0003). */
  @Override
  public Clock withZone(ZoneId zone) {
    throw new UnsupportedOperationException("MutableClock is UTC only");
  }
}
