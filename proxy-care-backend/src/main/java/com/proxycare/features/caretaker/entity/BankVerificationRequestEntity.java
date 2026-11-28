package com.proxycare.features.caretaker.entity;

import com.proxycare.common.crypto.AesGcmStringConverter;
import com.proxycare.common.persistence.BaseEntity;
import com.proxycare.features.caretaker.enums.BankVerificationFailureReason;
import com.proxycare.features.caretaker.enums.BankVerificationStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * One penny-drop attempt for a caretaker's payout account; earlier attempts stay as history. The account number
 * is held in plain text only in memory and stored encrypted.
 */
@Entity
@Table(name = "bank_verification_requests")
@Getter
@Setter
@NoArgsConstructor
public class BankVerificationRequestEntity extends BaseEntity {

    @Column(nullable = false, updatable = false)
    private UUID caretakerId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private BankVerificationStatus status;

    @Enumerated(EnumType.STRING)
    private BankVerificationFailureReason failureReason;

    @Column(nullable = false, updatable = false)
    private String accountHolderName;

    @Convert(converter = AesGcmStringConverter.class)
    @Column(name = "account_number_encrypted", nullable = false, updatable = false)
    private String accountNumber;

    @Column(name = "account_last4", nullable = false, updatable = false)
    private String accountLast4;

    @Column(nullable = false, updatable = false)
    private String ifsc;

    @Column(nullable = false, updatable = false)
    private String bankName;

    @Column(nullable = false, updatable = false)
    private String bankBranch;

    private String razorpayxContactId;

    private String razorpayxFundAccountId;

    @Column(unique = true)
    private String razorpayxValidationId;

    private Instant vendorRequestedAt;

    @Column(nullable = false)
    private Instant nextCheckAt;
}
