package com.proxycare.features.caretaker.repository;

import com.proxycare.features.caretaker.entity.BankVerificationRequestEntity;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BankVerificationRequestRepository extends JpaRepository<BankVerificationRequestEntity, UUID> {

    Optional<BankVerificationRequestEntity> findFirstByCaretakerIdOrderByCreatedAtDesc(UUID caretakerId);

    Optional<BankVerificationRequestEntity> findByRazorpayxValidationId(String razorpayxValidationId);

    /**
     * Locks the most overdue attempt in {@code status} for the rest of the transaction. SKIP LOCKED leaves rows
     * another job instance holds, so two instances never work on the same attempt.
     */
    @Query(value = """
            select * from bank_verification_requests
            where status = :status and next_check_at <= :now
            order by next_check_at
            limit 1
            for update skip locked
            """, nativeQuery = true)
    Optional<BankVerificationRequestEntity> lockNextDue(@Param("status") String status, @Param("now") Instant now);
}
