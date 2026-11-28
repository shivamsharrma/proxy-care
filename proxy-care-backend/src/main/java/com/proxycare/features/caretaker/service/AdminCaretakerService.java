package com.proxycare.features.caretaker.service;

import com.proxycare.common.exception.FieldValidationException;
import com.proxycare.features.caretaker.dto.request.KycDecisionRequest;
import com.proxycare.features.caretaker.dto.response.CaretakerResponse;
import com.proxycare.features.caretaker.entity.CaretakerEntity;
import com.proxycare.features.caretaker.enums.KycDecision;
import com.proxycare.features.caretaker.enums.OnboardingStatus;
import com.proxycare.features.caretaker.enums.VideoVerificationStatus;
import com.proxycare.features.caretaker.exception.CaretakerNotFoundException;
import com.proxycare.features.caretaker.exception.KycNotSubmittedException;
import com.proxycare.features.caretaker.mapper.CaretakerMapper;
import com.proxycare.features.caretaker.repository.CaretakerRepository;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AdminCaretakerService implements IAdminCaretakerService {

    private static final String REASON_FIELD = "reason";
    private static final String REASON_REQUIRED_MESSAGE = "must not be blank when rejecting";

    private final CaretakerRepository caretakerRepository;
    private final CaretakerMapper caretakerMapper;
    private final CaretakerActivation caretakerActivation;

    @Override
    @Transactional
    public CaretakerResponse decideKyc(UUID caretakerId, KycDecisionRequest kycDecisionRequest) {
        boolean rejected = kycDecisionRequest.decision() == KycDecision.REJECTED;
        if (rejected && kycDecisionRequest.reason() == null) {
            throw new FieldValidationException(REASON_FIELD, REASON_REQUIRED_MESSAGE);
        }

        CaretakerEntity caretakerEntity = caretakerRepository.findById(caretakerId)
                .orElseThrow(CaretakerNotFoundException::new);
        boolean submitted = caretakerEntity.getOnboardingStatus() == OnboardingStatus.SUBMITTED;
        boolean videoPending = caretakerEntity.getVideoVerificationStatus() == VideoVerificationStatus.PENDING;
        if (!submitted || !videoPending) {
            throw new KycNotSubmittedException();
        }

        caretakerEntity.setVideoVerificationStatus(
                rejected ? VideoVerificationStatus.REJECTED : VideoVerificationStatus.APPROVED);
        caretakerEntity.setRejectedReason(rejected ? kycDecisionRequest.reason() : null);
        caretakerActivation.activateIfReady(caretakerEntity);

        CaretakerEntity savedCaretakerEntity = caretakerRepository.save(caretakerEntity);
        return caretakerMapper.toCaretakerResponse(savedCaretakerEntity);
    }
}
