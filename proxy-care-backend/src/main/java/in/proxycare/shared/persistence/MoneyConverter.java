package in.proxycare.shared.persistence;

import in.proxycare.shared.money.Money;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/**
 * Stores {@link Money} as a {@code bigint} column of paise (ADR 0003). Applied automatically to
 * every {@code Money} attribute.
 */
@Converter(autoApply = true)
public class MoneyConverter implements AttributeConverter<Money, Long> {

  @Override
  public Long convertToDatabaseColumn(Money money) {
    return money == null ? null : money.paise();
  }

  @Override
  public Money convertToEntityAttribute(Long paise) {
    return paise == null ? null : Money.ofPaise(paise);
  }
}
