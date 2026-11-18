package in.proxycare.support.persistence;

import in.proxycare.shared.money.Money;
import in.proxycare.shared.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import org.hibernate.annotations.SoftDelete;

/**
 * TEST-ONLY entity over the test-only table {@code test_probe_entity}: exercises {@link
 * BaseEntity}, the {@code Money} converter and soft delete before any feature entity exists.
 */
@Entity
@Table(name = "test_probe_entity")
@SoftDelete // boolean column "deleted"; deleting sets it, queries exclude such rows
public class ProbeEntity extends BaseEntity {

  @Column(name = "name", nullable = false)
  private String name;

  @Column(name = "amount_paise", nullable = false)
  private Money amount;

  protected ProbeEntity() {}

  public ProbeEntity(String name, Money amount) {
    this.name = name;
    this.amount = amount;
  }

  public String getName() {
    return name;
  }

  public void rename(String newName) {
    this.name = newName;
  }

  public Money getAmount() {
    return amount;
  }
}
