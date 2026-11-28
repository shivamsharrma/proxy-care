package com.proxycare.features.caretaker.service;

import com.proxycare.features.caretaker.entity.BankVerificationRequestEntity;
import com.proxycare.features.caretaker.entity.CaretakerEntity;
import com.proxycare.features.caretaker.enums.BankVerificationFailureReason;
import com.proxycare.features.caretaker.enums.BankVerificationStatus;
import com.proxycare.features.caretaker.exception.CaretakerNotFoundException;
import com.proxycare.features.caretaker.repository.BankVerificationRequestRepository;
import com.proxycare.features.caretaker.repository.CaretakerRepository;
import com.proxycare.infrastructure.payout.NameMatchPolicy;
import com.proxycare.infrastructure.payout.model.BankVerification;
import com.proxycare.infrastructure.payout.model.BankVerificationVerdict;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * The one place a penny-drop outcome is applied, whether the webhook or BankVerificationJob saw it first. Runs in
 * the caller's transaction. Only a PENDING attempt changes, so a late or repeated outcome is harmless; a PENDING
 * attempt is always the caretaker's latest, so its outcome becomes the caretaker's bank verification status.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class BankVerificationOutcomeRecorder {

    private final BankVerificationRequestRepository bankVerificationRequestRepository;
    private final CaretakerRepository caretakerRepository;
    private final NameMatchPolicy nameMatchPolicy;
    private final CaretakerActivation caretakerActivation;

    public void recordOutcome(
            BankVerificationRequestEntity bankVerificationRequestEntity, BankVerification bankVerification) {
        if (bankVerificationRequestEntity.getStatus() != BankVerificationStatus.PENDING) {
            return;
        }
        BankVerificationVerdict bankVerificationVerdict =
                nameMatchPolicy.decide(bankVerification, bankVerificationRequestEntity.getAccountHolderName());
        if (bankVerificationVerdict == BankVerificationVerdict.PENDING) {
            return;
        }

        BankVerificationStatus bankVerificationStatus = bankVerificationVerdict == BankVerificationVerdict.VERIFIED
                ? BankVerificationStatus.VERIFIED
                : BankVerificationStatus.FAILED;
        bankVerificationRequestEntity.setStatus(bankVerificationStatus);
        bankVerificationRequestEntity.setFailureReason(toFailureReason(bankVerificationVerdict));
        bankVerificationRequestRepository.save(bankVerificationRequestEntity);

        CaretakerEntity caretakerEntity = caretakerRepository.findById(bankVerificationRequestEntity.getCaretakerId())
                .orElseThrow(CaretakerNotFoundException::new);
        caretakerEntity.setBankVerificationStatus(bankVerificationStatus);
        caretakerActivation.activateIfReady(caretakerEntity);
        caretakerRepository.save(caretakerEntity);

        log.info("Bank verification recorded bankVerificationRequestId={} caretakerId={} verdict={}",
                bankVerificationRequestEntity.getId(), caretakerEntity.getId(), bankVerificationVerdict);
    }

    private static BankVerificationFailureReason toFailureReason(BankVerificationVerdict bankVerificationVerdict) {
        return switch (bankVerificationVerdict) {
            case DEPOSIT_FAILED -> BankVerificationFailureReason.DEPOSIT_FAILED;
            case NAME_MISMATCH -> BankVerificationFailureReason.NAME_MISMATCH;
            case NAME_VERIFICATION_UNAVAILABLE -> BankVerificationFailureReason.NAME_VERIFICATION_UNAVAILABLE;
            case VERIFIED, PENDING -> null;
        };
    }
}
