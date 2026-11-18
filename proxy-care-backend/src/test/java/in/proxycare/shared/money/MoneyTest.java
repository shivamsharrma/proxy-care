package in.proxycare.shared.money;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.stream.LongStream;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class MoneyTest {

  private static Money paise(long paise) {
    return Money.ofPaise(paise);
  }

  @Nested
  class Creation {

    @Test
    void convertsWholeRupeesToPaise() {
      assertThat(Money.ofRupees(1_099)).isEqualTo(paise(109_900));
    }

    @Test
    void isAlwaysInr() {
      assertThat(Money.CURRENCY.getCurrencyCode()).isEqualTo("INR");
    }

    @Test
    void refusesRupeeAmountsThatOverflow() {
      assertThatThrownBy(() -> Money.ofRupees(Long.MAX_VALUE / 10))
          .isInstanceOf(ArithmeticException.class);
    }
  }

  @Nested
  class AdditionAndSubtraction {

    @Test
    void addsExactly() {
      // The PRD's wheelchair booking: 3 h x 250 + 400 margin + 99 fee.
      Money wage = Money.ofRupees(250).times(3);
      Money total = wage.plus(Money.ofRupees(400)).plus(Money.ofRupees(99));

      assertThat(total).isEqualTo(Money.ofRupees(1_249));
    }

    @Test
    void subtractsExactlyAndCanGoNegative() {
      assertThat(Money.ofRupees(1_249).minus(Money.ofRupees(99))).isEqualTo(Money.ofRupees(1_150));
      assertThat(paise(1).minus(paise(2))).isEqualTo(paise(-1));
    }

    @Test
    void addingZeroChangesNothing() {
      assertThat(paise(12_345).plus(Money.ZERO)).isEqualTo(paise(12_345));
    }

    @Test
    void refusesToOverflow() {
      assertThatThrownBy(() -> paise(Long.MAX_VALUE).plus(paise(1)))
          .isInstanceOf(ArithmeticException.class);
      assertThatThrownBy(() -> paise(Long.MIN_VALUE).minus(paise(1)))
          .isInstanceOf(ArithmeticException.class);
    }

    @Test
    void doesNotDriftLikeFloatingPoint() {
      // 0.1 + 0.2 != 0.3 in double; ten paise plus twenty paise is exactly thirty.
      Money sum =
          LongStream.range(0, 1_000).mapToObj(i -> paise(10)).reduce(Money.ZERO, Money::plus);

      assertThat(sum).isEqualTo(Money.ofRupees(100));
    }
  }

  @Nested
  class Multiplication {

    @Test
    void multipliesByWholeNumbersExactly() {
      assertThat(Money.ofRupees(320).times(3)).isEqualTo(Money.ofRupees(960));
    }

    @Test
    void refusesToOverflow() {
      assertThatThrownBy(() -> paise(Long.MAX_VALUE).times(2))
          .isInstanceOf(ArithmeticException.class);
    }

    @ParameterizedTest(name = "{0} paise x {1} rounded {2} = {3}")
    @CsvSource({
      "100, 0.333, HALF_UP, 33",
      "100, 0.335, HALF_UP, 34",
      "100, 0.335, HALF_EVEN, 34",
      "100, 0.325, HALF_EVEN, 32",
      "100, 0.339, DOWN, 33",
      "100, 0.331, UP, 34",
      "-100, 0.335, HALF_UP, -34",
      "20000, 0.5, UNNECESSARY, 10000"
    })
    void roundsFractionalProductsAsInstructed(
        long amount, String factor, RoundingMode rounding, long expected) {
      assertThat(paise(amount).times(new BigDecimal(factor), rounding)).isEqualTo(paise(expected));
    }

    @Test
    void refusesToRoundSilently() {
      assertThatThrownBy(() -> paise(100).times(new BigDecimal("0.333"), RoundingMode.UNNECESSARY))
          .isInstanceOf(ArithmeticException.class);
    }

    @Test
    void refusesFractionalProductsThatOverflow() {
      assertThatThrownBy(
              () -> paise(Long.MAX_VALUE).times(new BigDecimal("1.5"), RoundingMode.HALF_UP))
          .isInstanceOf(ArithmeticException.class);
    }
  }

  @Nested
  class Allocation {

    @Test
    void splitsEquallyWithLeftoverPaiseToTheFirstShares() {
      assertThat(paise(100).allocate(3)).containsExactly(paise(34), paise(33), paise(33));
    }

    @Test
    void splitsByRatioUsingTheLargestRemainder() {
      // 1000 x 1/3 = 333.33, 1000 x 2/3 = 666.67: the larger remainder gets the leftover paisa.
      assertThat(paise(1_000).allocate(1, 2)).containsExactly(paise(333), paise(667));
    }

    @Test
    void breaksRemainderTiesByOrder() {
      assertThat(paise(5).allocate(1, 1)).containsExactly(paise(3), paise(2));
    }

    @Test
    void allowsZeroRatios() {
      assertThat(paise(100).allocate(0, 1, 0)).containsExactly(Money.ZERO, paise(100), Money.ZERO);
    }

    @Test
    void splitsNegativeAmountsSymmetrically() {
      assertThat(paise(-100).allocate(3)).containsExactly(paise(-34), paise(-33), paise(-33));
    }

    @Test
    void splitsZero() {
      assertThat(Money.ZERO.allocate(4)).containsOnly(Money.ZERO).hasSize(4);
    }

    @ParameterizedTest(name = "{0} paise split by {1}")
    @CsvSource({
      "1, '1,1,1'",
      "7, '1,1,1,1,1,1,1,1,1,1'",
      "109900, '200,400,99'",
      "124900, '3,5,7,11,13'",
      "-999999, '1,2,3'",
      "9223372036854775807, '1,1,1'",
      "-9223372036854775808, '2,3'"
    })
    void alwaysAddsUpToTheOriginalAmount(long amount, String ratioList) {
      long[] ratios =
          java.util.Arrays.stream(ratioList.split(",")).mapToLong(Long::parseLong).toArray();

      List<Money> shares = paise(amount).allocate(ratios);

      assertThat(shares).hasSize(ratios.length);
      java.math.BigInteger sum =
          shares.stream()
              .map(share -> java.math.BigInteger.valueOf(share.paise()))
              .reduce(java.math.BigInteger.ZERO, java.math.BigInteger::add);
      assertThat(sum).isEqualTo(java.math.BigInteger.valueOf(amount));
    }

    @Test
    void sharesDifferByAtMostOnePaisaInAnEqualSplit() {
      List<Money> shares = paise(1_000_003).allocate(7);

      long smallest = shares.stream().mapToLong(Money::paise).min().orElseThrow();
      long largest = shares.stream().mapToLong(Money::paise).max().orElseThrow();
      assertThat(largest - smallest).isLessThanOrEqualTo(1);
    }

    @Test
    void returnsAnUnmodifiableList() {
      List<Money> shares = paise(10).allocate(2);

      assertThatThrownBy(() -> shares.add(Money.ZERO))
          .isInstanceOf(UnsupportedOperationException.class);
    }

    @Test
    void rejectsInvalidRatios() {
      assertThatIllegalArgumentException().isThrownBy(() -> paise(100).allocate(0));
      assertThatIllegalArgumentException().isThrownBy(() -> paise(100).allocate(new long[0]));
      assertThatIllegalArgumentException().isThrownBy(() -> paise(100).allocate(1, -1));
      assertThatIllegalArgumentException().isThrownBy(() -> paise(100).allocate(0, 0));
    }
  }

  @Nested
  class Comparison {

    @Test
    void comparesByAmount() {
      assertThat(paise(100)).isGreaterThan(paise(99)).isLessThan(paise(101));
      assertThat(paise(100).isGreaterThan(paise(99))).isTrue();
      assertThat(paise(99).isLessThan(paise(100))).isTrue();
      assertThat(paise(100).compareTo(paise(100))).isZero();
    }

    @Test
    void reportsItsSign() {
      assertThat(Money.ZERO.isZero()).isTrue();
      assertThat(paise(1).isPositive()).isTrue();
      assertThat(paise(-1).isNegative()).isTrue();
      assertThat(Money.ZERO.isPositive() || Money.ZERO.isNegative()).isFalse();
    }

    @Test
    void isEqualByValue() {
      assertThat(Money.ofRupees(5)).isEqualTo(paise(500)).hasSameHashCodeAs(paise(500));
      assertThat(paise(500)).isNotEqualTo(paise(501));
    }
  }

  @Nested
  class Formatting {

    @ParameterizedTest(name = "{0} paise -> {1}")
    @CsvSource(
        delimiter = '|',
        value = {
          "0 | ₹0.00",
          "5 | ₹0.05",
          "100 | ₹1.00",
          "109900 | ₹1,099.00",
          "12345678 | ₹1,23,456.78",
          "1000000000 | ₹1,00,00,000.00",
          "-124950 | -₹1,249.50",
          "-9223372036854775808 | -₹92,23,37,20,36,85,47,758.08"
        })
    void formatsWithIndianDigitGrouping(long amount, String expected) {
      assertThat(paise(amount).format()).isEqualTo(expected);
      assertThat(paise(amount)).hasToString(expected);
    }
  }
}
