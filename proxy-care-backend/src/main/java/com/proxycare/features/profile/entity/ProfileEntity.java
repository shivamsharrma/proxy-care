package com.proxycare.features.profile.entity;

import com.proxycare.common.security.authorization.Role;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.ZonedDateTime;
import java.util.Set;
import java.util.UUID;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

// Not a BaseEntity: the id comes from Supabase's auth.users, and the table has no updated_at or version.
@Entity
@Table(name = "profiles")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ProfileEntity {

    @Id
    private UUID id;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(nullable = false, columnDefinition = "app_role[]")
    private Set<Role> roles;

    @Column(nullable = false)
    private String phone;

    @Column(nullable = false)
    private String preferredLanguage;

    @Column(nullable = false, insertable = false, updatable = false)
    private ZonedDateTime createdAt;
}
