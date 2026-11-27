package com.proxycare.features.caretaker.service;

import com.proxycare.common.security.identity.ISecurityIdentityProvider;
import com.proxycare.features.caretaker.dto.response.KycProgressResponse;
import com.proxycare.features.caretaker.dto.response.KycStepResponse;
import com.proxycare.features.caretaker.entity.CaretakerEntity;
import com.proxycare.features.caretaker.enums.CaretakerStatus;
import com.proxycare.features.caretaker.enums.KycStep;
import com.proxycare.features.caretaker.enums.KycStepState;
import com.proxycare.features.caretaker.enums.OnboardingStatus;
import com.proxycare.features.caretaker.enums.VideoVerificationStatus;
import com.proxycare.features.caretaker.exception.CaretakerNotFoundException;
import com.proxycare.features.caretaker.mapper.CaretakerMapper;
import com.proxycare.features.caretaker.repository.CaretakerRepository;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CaretakerService implements ICaretakerService {

    private static final int TOTAL_STEPS = KycStep.values().length;
    private static final int BASIC_INFORMATION_STEP_NUMBER = KycStep.BASIC_INFORMATION.getStepNumber();

    private final CaretakerRepository caretakerRepository;
    private final CaretakerMapper caretakerMapper;
    private final ISecurityIdentityProvider securityIdentityProvider;

    @Override
    @Transactional
    public void ensureCurrentCaretaker() {
        UUID profileId = securityIdentityProvider.getAuthenticatedUserId();
        if (caretakerRepository.existsByProfileId(profileId)) {
            return;
        }

        caretakerRepository.save(buildOnboardingCaretakerEntity(profileId));
    }

    @Override
    @Transactional(readOnly = true)
    public KycProgressResponse getCurrentKycProgress() {
        CaretakerEntity caretakerEntity = caretakerRepository.findByProfileId(
                        securityIdentityProvider.getAuthenticatedUserId())
                .orElseThrow(CaretakerNotFoundException::new);

        boolean checklistFinished = caretakerEntity.getOnboardingStatus() != OnboardingStatus.IN_PROGRESS;
        int stepNumber = checklistFinished ? TOTAL_STEPS : caretakerEntity.getKycStep();
        List<KycStepResponse> kycStepResponses = Arrays.stream(KycStep.values())
                .map(kycStep -> new KycStepResponse(kycStep, toKycStepState(kycStep, stepNumber, checklistFinished)))
                .toList();

        return caretakerMapper.toKycProgressResponse(caretakerEntity, stepNumber, TOTAL_STEPS, kycStepResponses);
    }

    private static CaretakerEntity buildOnboardingCaretakerEntity(UUID profileId) {
        CaretakerEntity caretakerEntity = new CaretakerEntity();
        caretakerEntity.setProfileId(profileId);
        caretakerEntity.setStatus(CaretakerStatus.PENDING);
        caretakerEntity.setOnboardingStatus(OnboardingStatus.IN_PROGRESS);
        caretakerEntity.setVideoVerificationStatus(VideoVerificationStatus.PENDING);
        caretakerEntity.setKycStep(BASIC_INFORMATION_STEP_NUMBER);
        return caretakerEntity;
    }

    private static KycStepState toKycStepState(KycStep kycStep, int currentStepNumber, boolean checklistFinished) {
        int kycStepNumber = kycStep.getStepNumber();
        if (checklistFinished || kycStepNumber < currentStepNumber) {
            return KycStepState.DONE;
        }
        return kycStepNumber == currentStepNumber ? KycStepState.CURRENT : KycStepState.TODO;
    }
}
