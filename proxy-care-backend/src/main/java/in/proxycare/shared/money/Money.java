package in.proxycare.shared.money;

import java.math.BigDecimal;
import java.math.BigInteger;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.Currency;
import java.util.List;
import java.util.Objects;
import java.util.stream.IntStream;

/**
 * An exact amount of Indian rupees, held as a whole number of paise (1 rupee = 100 paise).
 *
 * <p>Immutable, and never floating point. Arithmetic that would overflow {@code long} throws {@link
 * ArithmeticException} instead of wrapping. Rounding happens only where a caller asks for it with
 * an explicit {@link RoundingMode}. Amounts may be negative (for example a difference between two
 * amounts); whether a negative amount is acceptable is the caller's business rule.
 *
 * @param paise the amount in paise
 */
public record Money(long paise) implements Comparable<Money> {

  /** The only currency: Proxy Care is INR-only. */
  public static final Currency CURRENCY = Currency.getInstance("INR");

  public static final Money ZERO = new Money(0);

  private static final long PAISE_PER_RUPEE = 100;

  public static Money ofPaise(long paise) {
    return new Money(paise);
  }

  /** Whole rupees: {@code ofRupees(1099)} is 109,900 paise. */
  public static Money ofRupees(long rupees) {
    return new Money(Math.multiplyExact(rupees, PAISE_PER_RUPEE));
  }

  public Money plus(Money other) {
    return new Money(Math.addExact(paise, other.paise));
  }

  public Money minus(Money other) {
    return new Money(Math.subtractExact(paise, other.paise));
  }

  /** Exact multiplication by a whole number, for example a wage times whole hours. */
  public Money times(long factor) {
    return new Money(Math.multiplyExact(paise, factor));
  }

  /**
   * Multiplication by a fractional factor, rounded to whole paise with {@code rounding}. {@link
   * RoundingMode#UNNECESSARY} asserts the result is exact and throws otherwise.
   */
  public Money times(BigDecimal factor, RoundingMode rounding) {
    Objects.requireNonNull(factor, "factor");
    Objects.requireNonNull(rounding, "rounding");
    BigDecimal exact = BigDecimal.valueOf(paise).multiply(factor);
    return new Money(exact.setScale(0, rounding).longValueExact());
  }

  /**
   * Splits into {@code parts} amounts that differ by at most one paisa and add up exactly to this
   * amount. The first shares receive the leftover paise: {@code ofPaise(100).allocate(3)} is [34,
   * 33, 33].
   */
  public List<Money> allocate(int parts) {
    if (parts < 1) {
      throw new IllegalArgumentException("parts must be at least 1");
    }
    long[] ratios = new long[parts];
    Arrays.fill(ratios, 1);
    return allocate(ratios);
  }

  /**
   * Splits in proportion to {@code ratios}, adding up exactly to this amount (largest remainder
   * method). Each share is rounded down; the leftover paise go one each to the shares that lost the
   * most to rounding, earlier shares first on ties. {@code ofPaise(1000).allocate(1, 2)} is [333,
   * 667].
   *
   * @param ratios non-negative weights, at least one of them positive
   */
  public List<Money> allocate(long... ratios) {
    Objects.requireNonNull(ratios, "ratios");
    if (ratios.length == 0) {
      throw new IllegalArgumentException("at least one ratio is required");
    }
    BigInteger total = BigInteger.ZERO;
    for (long ratio : ratios) {
      if (ratio < 0) {
        throw new IllegalArgumentException("ratios must not be negative");
      }
      total = total.add(BigInteger.valueOf(ratio));
    }
    if (total.signum() == 0) {
      throw new IllegalArgumentException("at least one ratio must be positive");
    }

    // Work on the magnitude so rounding is symmetric for negative amounts.
    BigInteger magnitude = BigInteger.valueOf(paise).abs();
    BigInteger[] shares = new BigInteger[ratios.length];
    BigInteger[] remainders = new BigInteger[ratios.length];
    BigInteger allocated = BigInteger.ZERO;
    for (int i = 0; i < ratios.length; i++) {
      BigInteger[] division =
          magnitude.multiply(BigInteger.valueOf(ratios[i])).divideAndRemainder(total);
      shares[i] = division[0];
      remainders[i] = division[1];
      allocated = allocated.add(shares[i]);
    }
    int leftover = magnitude.subtract(allocated).intValueExact(); // < ratios.length
    IntStream.range(0, ratios.length)
        .boxed()
        .sorted(
            Comparator.<Integer, BigInteger>comparing(i -> remainders[i])
                .reversed()
                .thenComparing(Comparator.naturalOrder()))
        .limit(leftover)
        .forEach(i -> shares[i] = shares[i].add(BigInteger.ONE));

    List<Money> result = new ArrayList<>(ratios.length);
    for (BigInteger share : shares) {
      BigInteger signed = paise < 0 ? share.negate() : share;
      result.add(new Money(signed.longValueExact()));
    }
    return Collections.unmodifiableList(result);
  }

  public boolean isZero() {
    return paise == 0;
  }

  public boolean isPositive() {
    return paise > 0;
  }

  public boolean isNegative() {
    return paise < 0;
  }

  public boolean isGreaterThan(Money other) {
    return compareTo(other) > 0;
  }

  public boolean isLessThan(Money other) {
    return compareTo(other) < 0;
  }

  @Override
  public int compareTo(Money other) {
    return Long.compare(paise, other.paise);
  }

  /**
   * For people: rupee sign, Indian digit grouping, always two decimals. {@code ofPaise(12345678)}
   * is "₹1,23,456.78"; negative amounts start with "-". Locale-independent.
   */
  public String format() {
    BigInteger magnitude = BigInteger.valueOf(paise).abs();
    BigInteger[] rupeesAndPaise = magnitude.divideAndRemainder(BigInteger.valueOf(PAISE_PER_RUPEE));
    String fraction = String.format("%02d", rupeesAndPaise[1].intValue());
    return (paise < 0 ? "-" : "")
        + "₹"
        + groupIndian(rupeesAndPaise[0].toString())
        + "."
        + fraction;
  }

  /** Indian grouping: the last three digits, then groups of two (12,34,567). */
  private static String groupIndian(String digits) {
    if (digits.length() <= 3) {
      return digits;
    }
    String lastThree = digits.substring(digits.length() - 3);
    String rest = digits.substring(0, digits.length() - 3);
    StringBuilder grouped = new StringBuilder();
    int firstGroup = rest.length() % 2 == 0 ? 2 : 1;
    grouped.append(rest, 0, firstGroup);
    for (int i = firstGroup; i < rest.length(); i += 2) {
      grouped.append(',').append(rest, i, i + 2);
    }
    return grouped.append(',').append(lastThree).toString();
  }

  /** Same as {@link #format()}; safe for logs (an amount is not personal data). */
  @Override
  public String toString() {
    return format();
  }
}
