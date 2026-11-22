package com.proxycare.features.profile.entity;

import com.proxycare.common.security.authorization.Role;
import com.proxycare.features.profile.enums.PreferredLanguage;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.ZonedDateTime;
import java.util.Set;
import java.util.UUID;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.ColumnTransformer;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

// Not a BaseEntity: the id comes from Supabase's auth.users, and the table has no updated_at.
@Entity
@Table(name = "profiles")
@EntityListeners(AuditingEntityListener.class)
@Getter
@Setter
@NoArgsConstructor
public class ProfileEntity {

    @Id
    private UUID id;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(nullable = false, columnDefinition = "app_role[]")
    // Hibernate binds the array as varchar[]; Postgres does not cast that to app_role[] implicitly.
    @ColumnTransformer(write = "?::app_role[]")
    private Set<Role> roles;

    @Column(nullable = false)
    private String phone;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PreferredLanguage preferredLanguage;

    @CreatedDate
    @Column(nullable = false, updatable = false)
    @Setter(AccessLevel.NONE)
    private ZonedDateTime createdAt;

    @Version
    @Setter(AccessLevel.NONE)
    private Long version;
}
