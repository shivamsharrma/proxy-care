package com.proxycare.features.patient.entity;

import com.proxycare.common.model.MobileNumber;
import com.proxycare.common.model.Sex;
import com.proxycare.common.persistence.BaseEntity;
import com.proxycare.features.patient.enums.MobilityCategory;
import com.proxycare.features.patient.enums.Relation;
import jakarta.persistence.AttributeOverride;
import jakarta.persistence.Column;
import jakarta.persistence.Embedded;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.time.ZonedDateTime;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.ColumnTransformer;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "patients")
@Getter
@Setter
@NoArgsConstructor
public class PatientEntity extends BaseEntity {

    /** The owning app_users row. */
    @Column(nullable = false, updatable = false)
    private UUID userId;

    // Hibernate binds enum names as varchar; Postgres does not cast that to the enum types implicitly.
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "relation_type")
    @ColumnTransformer(write = "?::relation_type")
    private Relation relation;

    @Column(nullable = false)
    private String fullName;

    // The column is smallint; without this, schema validation expects integer.
    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(nullable = false)
    private Integer age;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "sex_type")
    @ColumnTransformer(write = "?::sex_type")
    private Sex sex;

    // Both columns null loads as a null mobile.
    @Embedded
    @AttributeOverride(name = "countryCode", column = @Column(name = "mobile_country_code"))
    @AttributeOverride(name = "number", column = @Column(name = "mobile_number"))
    private MobileNumber mobile;

    @Column(nullable = false)
    private boolean livesAtUserAddress;

    @Column(nullable = false)
    private String address;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "mobility_category")
    @ColumnTransformer(write = "?::mobility_category")
    private MobilityCategory mobility;

    private String healthNotes;

    private ZonedDateTime deletedAt;
}
