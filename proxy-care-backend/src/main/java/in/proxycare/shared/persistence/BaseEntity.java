package in.proxycare.shared.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.Hibernate;
import org.hibernate.annotations.UuidGenerator;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

/**
 * Columns every persistent entity has (docs/DATABASE.md): a time-ordered UUID id, an
 * optimistic-locking version and audit timestamps from the application clock.
 *
 * <p>Table columns: {@code id uuid primary key, version bigint not null, created_at timestamptz not
 * null, updated_at timestamptz not null}.
 *
 * <p>Equality is by id once assigned (on persist); a new, unsaved entity is equal only to itself.
 * The hash code is constant per class so it does not change when the id is assigned.
 */
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

  /** UUID version 7: time-ordered, so new rows append to the primary-key index. */
  @Id
  @UuidGenerator(style = UuidGenerator.Style.VERSION_7)
  @Column(name = "id", nullable = false, updatable = false)
  private UUID id;

  /** Incremented on every update; a stale update fails instead of overwriting (409 CONFLICT). */
  @Version
  @Column(name = "version", nullable = false)
  private long version;

  @CreatedDate
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @LastModifiedDate
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  protected BaseEntity() {}

  /** Null until the entity is persisted. */
  public UUID getId() {
    return id;
  }

  public long getVersion() {
    return version;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }

  @Override
  public final boolean equals(Object other) {
    if (this == other) {
      return true;
    }
    if (other == null || Hibernate.getClass(this) != Hibernate.getClass(other)) {
      return false;
    }
    return id != null && id.equals(((BaseEntity) other).id);
  }

  @Override
  public final int hashCode() {
    return Hibernate.getClass(this).hashCode();
  }
}
