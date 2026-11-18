package in.proxycare.shared.time;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Objects;
import org.springframework.stereotype.Component;

/**
 * Converts between stored instants (UTC) and business wall-clock time in India.
 *
 * <p>Conventions (ADR 0003): every instant is persisted and exchanged in UTC; calendar dates and
 * wall-clock times that people see or choose (a visit date, a pickup time) are interpreted in
 * {@link #ZONE}. India has had no daylight-saving time since 1945, so every local time maps to
 * exactly one instant.
 */
@Component
public class BusinessTime {

  public static final ZoneId ZONE = ZoneId.of("Asia/Kolkata");

  private final Clock clock;

  public BusinessTime(Clock clock) {
    this.clock = clock;
  }

  public Instant now() {
    return clock.instant();
  }

  /** Today's date in India, which differs from the UTC date between 00:00 and 05:30 IST. */
  public LocalDate today() {
    return LocalDate.ofInstant(clock.instant(), ZONE);
  }

  public ZonedDateTime inBusinessZone(Instant instant) {
    return Objects.requireNonNull(instant, "instant").atZone(ZONE);
  }

  /** The instant at which it is {@code time} on {@code date} in India. */
  public Instant toInstant(LocalDate date, LocalTime time) {
    Objects.requireNonNull(date, "date");
    Objects.requireNonNull(time, "time");
    return date.atTime(time).atZone(ZONE).toInstant();
  }

  /** Midnight at the start of {@code date} in India. */
  public Instant startOfDay(LocalDate date) {
    return Objects.requireNonNull(date, "date").atStartOfDay(ZONE).toInstant();
  }
}
