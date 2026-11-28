package com.proxycare.features.caretaker.service;

import com.proxycare.common.exception.SystemException;
import com.proxycare.features.caretaker.config.BankVerificationJobProperties;
import com.proxycare.features.caretaker.entity.BankVerificationRequestEntity;
import com.proxycare.features.caretaker.enums.BankVerificationStatus;
import com.proxycare.features.caretaker.repository.BankVerificationRequestRepository;
import com.proxycare.infrastructure.payout.gateway.IBankVerificationService;
import com.proxycare.infrastructure.payout.model.BankVerification;
import com.proxycare.infrastructure.payout.model.BankVerificationCommand;
import java.time.Clock;
import java.time.Instant;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Moves one due PENDING penny-drop attempt forward, in its own transaction, for BankVerificationJob. The attempt's
 * row stays locked (FOR UPDATE SKIP LOCKED) through the vendor calls, so no other job instance touches it.
 * <p>
 * Never two deposits for one attempt: before sending, it always looks for a deposit already tagged with the
 * attempt's id, because a run that sent one may have died before committing {@code vendor_requested_at}.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BankVerificationAttemptProcessor {

    private final BankVerificationRequestRepository bankVerificationRequestRepository;
    private final IBankVerificationService bankVerificationService;
    private final BankVerificationOutcomeRecorder bankVerificationOutcomeRecorder;
    private final BankVerificationJobProperties bankVerificationJobProperties;
    private final Clock clock;

    /** Handles the most overdue attempt; false when none is due. */
    @Transactional
    public boolean processNextDueAttempt() {
        Optional<BankVerificationRequestEntity> dueBankVerificationRequestEntity = bankVerificationRequestRepository
                .lockNextDue(BankVerificationStatus.PENDING.name(), clock.instant());
        if (dueBankVerificationRequestEntity.isEmpty()) {
            return false;
        }

        BankVerificationRequestEntity bankVerificationRequestEntity = dueBankVerificationRequestEntity.get();
        try {
            if (bankVerificationRequestEntity.getVendorRequestedAt() == null) {
                requestVerificationOnce(bankVerificationRequestEntity);
            } else {
                checkVerification(bankVerificationRequestEntity);
            }
        } catch (SystemException systemException) {
            // Ids and the code only: the vendor's exception text may hold request details.
            log.warn("Bank verification vendor call failed bankVerificationRequestId={} code={}",
                    bankVerificationRequestEntity.getId(), systemException.getErrorCode());
            bankVerificationRequestEntity.setNextCheckAt(clock.instant().plus(bankVerificationJobProperties.pollInterval()));
        }
        bankVerificationRequestRepository.save(bankVerificationRequestEntity);
        return true;
    }

    private void requestVerificationOnce(BankVerificationRequestEntity bankVerificationRequestEntity) {
        BankVerification bankVerification = bankVerificationService
                .findVerificationByRequestId(bankVerificationRequestEntity.getId())
                .orElseGet(() -> bankVerificationService.requestVerification(
                        buildBankVerificationCommand(bankVerificationRequestEntity)));

        Instant now = clock.instant();
        bankVerificationRequestEntity.setRazorpayxContactId(bankVerification.contactId());
        bankVerificationRequestEntity.setRazorpayxFundAccountId(bankVerification.fundAccountId());
        bankVerificationRequestEntity.setRazorpayxValidationId(bankVerification.validationId());
        bankVerificationRequestEntity.setVendorRequestedAt(now);
        bankVerificationRequestEntity.setNextCheckAt(now.plus(bankVerificationJobProperties.firstCheckDelay()));
        bankVerificationOutcomeRecorder.recordOutcome(bankVerificationRequestEntity, bankVerification);
        log.info("Bank verification requested bankVerificationRequestId={}", bankVerificationRequestEntity.getId());
    }

    private void checkVerification(BankVerificationRequestEntity bankVerificationRequestEntity) {
        BankVerification bankVerification =
                bankVerificationService.fetchVerification(bankVerificationRequestEntity.getRazorpayxValidationId());

        bankVerificationRequestEntity.setNextCheckAt(clock.instant().plus(bankVerificationJobProperties.pollInterval()));
        bankVerificationOutcomeRecorder.recordOutcome(bankVerificationRequestEntity, bankVerification);
    }

    private static BankVerificationCommand buildBankVerificationCommand(
            BankVerificationRequestEntity bankVerificationRequestEntity) {
        return new BankVerificationCommand(
                bankVerificationRequestEntity.getId(),
                bankVerificationRequestEntity.getCaretakerId(),
                bankVerificationRequestEntity.getAccountHolderName(),
                bankVerificationRequestEntity.getAccountNumber(),
                bankVerificationRequestEntity.getIfsc());
    }
}
