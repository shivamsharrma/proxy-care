package com.proxycare.features.caretaker.service;

import com.proxycare.common.security.identity.ISecurityIdentityProvider;
import com.proxycare.features.bank.dto.response.BankBranchResponse;
import com.proxycare.features.bank.service.IBankBranchService;
import com.proxycare.features.caretaker.dto.request.SavePayoutAccountRequest;
import com.proxycare.features.caretaker.dto.response.PayoutAccountResponse;
import com.proxycare.features.caretaker.entity.BankVerificationRequestEntity;
import com.proxycare.features.caretaker.entity.CaretakerEntity;
import com.proxycare.features.caretaker.enums.BankVerificationStatus;
import com.proxycare.features.caretaker.enums.KycStep;
import com.proxycare.features.caretaker.enums.OnboardingStatus;
import com.proxycare.features.caretaker.exception.CaretakerNotFoundException;
import com.proxycare.features.caretaker.exception.KycStepLockedException;
import com.proxycare.features.caretaker.exception.PayoutAccountNotFoundException;
import com.proxycare.features.caretaker.mapper.CaretakerMapper;
import com.proxycare.features.caretaker.repository.BankVerificationRequestRepository;
import com.proxycare.features.caretaker.repository.CaretakerRepository;
import java.time.Clock;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CaretakerPayoutService implements ICaretakerPayoutService {

    private static final int PAYOUT_ACCOUNT_STEP_NUMBER = KycStep.PAYOUT_ACCOUNT.getStepNumber();
    private static final int LAST4_LENGTH = 4;

    private final CaretakerRepository caretakerRepository;
    private final BankVerificationRequestRepository bankVerificationRequestRepository;
    private final IBankBranchService bankBranchService;
    private final CaretakerMapper caretakerMapper;
    private final ISecurityIdentityProvider securityIdentityProvider;
    private final Clock clock;

    // A double submit can't send two deposits: the second sees bank PENDING (KYC_STEP_LOCKED), and two at once
    // both update the caretakers row, so one loses on @Version (CONCURRENT_MODIFICATION) and its attempt rolls back.
    @Override
    @Transactional
    public PayoutAccountResponse saveCurrentPayoutAccount(SavePayoutAccountRequest savePayoutAccountRequest) {
        CaretakerEntity caretakerEntity = findCurrentCaretakerEntity();
        if (!isPayoutAccountOpen(caretakerEntity)) {
            throw new KycStepLockedException();
        }
        BankBranchResponse bankBranchResponse = bankBranchService.getBankBranch(savePayoutAccountRequest.ifsc());

        BankVerificationRequestEntity bankVerificationRequestEntity = buildPendingBankVerificationRequestEntity(
                caretakerEntity.getId(), savePayoutAccountRequest, bankBranchResponse);
        BankVerificationRequestEntity savedBankVerificationRequestEntity =
                bankVerificationRequestRepository.save(bankVerificationRequestEntity);

        caretakerEntity.setBankVerificationStatus(BankVerificationStatus.PENDING);
        caretakerEntity.setOnboardingStatus(OnboardingStatus.SUBMITTED);
        caretakerRepository.save(caretakerEntity);

        return caretakerMapper.toPayoutAccountResponse(savedBankVerificationRequestEntity);
    }

    @Override
    @Transactional(readOnly = true)
    public PayoutAccountResponse getCurrentPayoutAccount() {
        CaretakerEntity caretakerEntity = findCurrentCaretakerEntity();
        return bankVerificationRequestRepository.findFirstByCaretakerIdOrderByCreatedAtDesc(caretakerEntity.getId())
                .map(caretakerMapper::toPayoutAccountResponse)
                .orElseThrow(PayoutAccountNotFoundException::new);
    }

    private CaretakerEntity findCurrentCaretakerEntity() {
        return caretakerRepository.findByProfileId(securityIdentityProvider.getAuthenticatedUserId())
                .orElseThrow(CaretakerNotFoundException::new);
    }

    /** The first submit at step 4, or a resubmit after the bank check failed. */
    private static boolean isPayoutAccountOpen(CaretakerEntity caretakerEntity) {
        OnboardingStatus onboardingStatus = caretakerEntity.getOnboardingStatus();
        boolean firstSubmit = onboardingStatus == OnboardingStatus.IN_PROGRESS
                && caretakerEntity.getKycStep() >= PAYOUT_ACCOUNT_STEP_NUMBER;
        boolean resubmitAfterFailure = onboardingStatus == OnboardingStatus.SUBMITTED
                && caretakerEntity.getBankVerificationStatus() == BankVerificationStatus.FAILED;
        return firstSubmit || resubmitAfterFailure;
    }

    // Due at once: the job picks it up on its next run.
    private BankVerificationRequestEntity buildPendingBankVerificationRequestEntity(
            UUID caretakerId, SavePayoutAccountRequest savePayoutAccountRequest, BankBranchResponse bankBranchResponse) {
        String accountNumber = savePayoutAccountRequest.accountNumber();
        BankVerificationRequestEntity bankVerificationRequestEntity = new BankVerificationRequestEntity();
        bankVerificationRequestEntity.setCaretakerId(caretakerId);
        bankVerificationRequestEntity.setStatus(BankVerificationStatus.PENDING);
        bankVerificationRequestEntity.setAccountHolderName(savePayoutAccountRequest.accountHolderName());
        bankVerificationRequestEntity.setAccountNumber(accountNumber);
        bankVerificationRequestEntity.setAccountLast4(accountNumber.substring(accountNumber.length() - LAST4_LENGTH));
        bankVerificationRequestEntity.setIfsc(savePayoutAccountRequest.ifsc());
        bankVerificationRequestEntity.setBankName(bankBranchResponse.bankName());
        bankVerificationRequestEntity.setBankBranch(bankBranchResponse.branch());
        bankVerificationRequestEntity.setNextCheckAt(clock.instant());
        return bankVerificationRequestEntity;
    }
}
