package com.proxycare.features.caretaker.entity;

import com.proxycare.common.persistence.BaseEntity;
import com.proxycare.features.caretaker.enums.BankVerificationStatus;
import com.proxycare.features.caretaker.enums.CaretakerStatus;
import com.proxycare.features.caretaker.enums.OnboardingStatus;
import com.proxycare.features.caretaker.enums.VideoVerificationStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

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
}
