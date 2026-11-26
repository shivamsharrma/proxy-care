package com.proxycare.features.user.entity;

import com.proxycare.common.model.Sex;
import com.proxycare.common.persistence.BaseEntity;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
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
    @Column(nullable = false)
    private Sex sex;

    // The column is smallint; without this, schema validation expects integer.
    @JdbcTypeCode(SqlTypes.SMALLINT)
    private Integer age;

    @Column(nullable = false)
    private String address;

    // Unidirectional: the non-updatable join column makes Hibernate write user_id in the patient's own insert.
    // A patient taken out of this list is an orphan; PatientEntity's @SoftDelete turns its delete into setting
    // deleted_at and keeps deleted patients out of every load.
    @OneToMany(cascade = CascadeType.ALL, orphanRemoval = true)
    @JoinColumn(name = "user_id", nullable = false, updatable = false)
    @OrderBy("createdAt, id")
    @Setter(AccessLevel.NONE)
    private List<PatientEntity> patients = new ArrayList<>();
}
