package com.proxycare.features.user.entity;

import com.proxycare.common.model.Sex;
import com.proxycare.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.ColumnTransformer;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "app_users")
@Getter
@Setter
@NoArgsConstructor
public class AppUserEntity extends BaseEntity {

    @Column(nullable = false, updatable = false, unique = true)
    private UUID profileId;

    @Column(nullable = false)
    private String fullName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "sex_type")
    // Hibernate binds the enum name as varchar; Postgres does not cast that to sex_type implicitly.
    @ColumnTransformer(write = "?::sex_type")
    private Sex sex;

    // The column is smallint; without this, schema validation expects integer.
    @JdbcTypeCode(SqlTypes.SMALLINT)
    private Integer age;

    @Column(nullable = false)
    private String address;
}
