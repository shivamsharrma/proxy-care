package com.proxycare.features.user.entity;

import com.proxycare.common.model.MobileNumber;
import com.proxycare.common.model.Sex;
import com.proxycare.common.persistence.BaseEntity;
import com.proxycare.features.user.enums.MobilityCategory;
import com.proxycare.features.user.enums.Relation;
import jakarta.persistence.AttributeOverride;
import jakarta.persistence.Column;
import jakarta.persistence.Embedded;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.SoftDelete;
import org.hibernate.annotations.SoftDeleteType;
import org.hibernate.type.SqlTypes;

/**
 * A family member a User books for. AppUserEntity owns the relationship and writes user_id. Deleting one only sets
 * deleted_at (bookings will still point at it), and Hibernate leaves deleted patients out of every query.
 */
@Entity
@SoftDelete(strategy = SoftDeleteType.TIMESTAMP, columnName = "deleted_at")
@Table(name = "patients")
@Getter
@Setter
@NoArgsConstructor
public class PatientEntity extends BaseEntity {

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Relation relation;

    @Column(nullable = false)
    private String fullName;

    // The column is smallint; without this, schema validation expects integer.
    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(nullable = false)
    private Integer age;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Sex sex;

    // Both columns null loads as a null mobile.
    @Embedded
    @AttributeOverride(name = "countryCode", column = @Column(name = "mobile_country_code"))
    @AttributeOverride(name = "number", column = @Column(name = "mobile_number"))
    private MobileNumber mobile;

    @Column(nullable = false)
    private String address;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private MobilityCategory mobilityCategory;

    private String healthNotes;
}
