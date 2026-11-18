package in.proxycare.shared.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import in.proxycare.shared.money.Money;
import org.junit.jupiter.api.Test;

class MoneyConverterTest {

  private final MoneyConverter converter = new MoneyConverter();

  @Test
  void storesPaiseAsALong() {
    assertThat(converter.convertToDatabaseColumn(Money.ofRupees(1_249))).isEqualTo(124_900L);
    assertThat(converter.convertToEntityAttribute(124_900L)).isEqualTo(Money.ofRupees(1_249));
  }

  @Test
  void passesNullThrough() {
    assertThat(converter.convertToDatabaseColumn(null)).isNull();
    assertThat(converter.convertToEntityAttribute(null)).isNull();
  }
}
