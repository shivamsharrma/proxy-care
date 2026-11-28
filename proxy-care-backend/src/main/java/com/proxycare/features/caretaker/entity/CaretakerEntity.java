package com.proxycare.features.caretaker.entity;

import com.proxycare.common.model.MobileNumber;
import com.proxycare.common.model.Sex;
import com.proxycare.common.persistence.BaseEntity;
import com.proxycare.features.caretaker.enums.BankVerificationStatus;
import com.proxycare.features.caretaker.enums.CaretakerStatus;
import com.proxycare.features.caretaker.enums.MaritalStatus;
import com.proxycare.features.caretaker.enums.OnboardingStatus;
import com.proxycare.features.caretaker.enums.VideoVerificationStatus;
import jakarta.persistence.AttributeOverride;
import jakarta.persistence.Column;
import jakarta.persistence.Embedded;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/** One caretaker per CARETAKER profile. The KYC columns stay null until their step is saved. */
@Entity
@Table(name = "caretakers")
@Getter
@Setter
@NoArgsConstructor
public class CaretakerEntity extends BaseEntity {

    @Column(nullable = false, updatable = false, unique = true)
    private UUID profileId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private CaretakerStatus status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OnboardingStatus onboardingStatus;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private VideoVerificationStatus videoVerificationStatus;

    @Enumerated(EnumType.STRING)
    private BankVerificationStatus bankVerificationStatus;

    // The column is smallint; without this, schema validation expects integer.
    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(nullable = false)
    private Integer kycStep;

    private String rejectedReason;

    private String fullName;

    @Enumerated(EnumType.STRING)
    private Sex sex;

    // The column is smallint; without this, schema validation expects integer.
    @JdbcTypeCode(SqlTypes.SMALLINT)
    private Integer age;

    private String email;

    // Both columns null loads as a null emergency contact.
    @Embedded
    @AttributeOverride(name = "countryCode", column = @Column(name = "emergency_contact_country_code"))
    @AttributeOverride(name = "number", column = @Column(name = "emergency_contact_number"))
    private MobileNumber emergencyContact;

    private String residentialAddress;

    private String occupation;

    @Enumerated(EnumType.STRING)
    private MaritalStatus maritalStatus;

    @JdbcTypeCode(SqlTypes.JSON)
    private BasicInformationDraft basicInformationDraft;

    private UUID photoFileId;

    private Instant vkycSlotAt;
}
