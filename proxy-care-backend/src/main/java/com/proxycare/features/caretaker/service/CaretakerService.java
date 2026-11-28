package com.proxycare.features.caretaker.service;

import com.proxycare.common.exception.FieldValidationException;
import com.proxycare.common.security.identity.AuthenticatedUser;
import com.proxycare.common.security.identity.ISecurityIdentityProvider;
import com.proxycare.features.caretaker.dto.request.PhotoFileRequest;
import com.proxycare.features.caretaker.dto.request.SaveBasicInformationRequest;
import com.proxycare.features.caretaker.dto.request.SaveIdentityCheckRequest;
import com.proxycare.features.caretaker.dto.request.VkycBookingRequest;
import com.proxycare.features.caretaker.dto.response.BasicInformationDraftResponse;
import com.proxycare.features.caretaker.dto.response.CaretakerResponse;
import com.proxycare.features.caretaker.dto.response.KycProgressResponse;
import com.proxycare.features.caretaker.dto.response.KycStepResponse;
import com.proxycare.features.caretaker.entity.BankVerificationRequestEntity;
import com.proxycare.features.caretaker.entity.BasicInformationDraft;
import com.proxycare.features.caretaker.entity.CaretakerEntity;
import com.proxycare.features.caretaker.entity.FileEntity;
import com.proxycare.features.caretaker.enums.BankVerificationFailureReason;
import com.proxycare.features.caretaker.enums.BankVerificationStatus;
import com.proxycare.features.caretaker.enums.CaretakerStatus;
import com.proxycare.features.caretaker.enums.FileKind;
import com.proxycare.features.caretaker.enums.KycStep;
import com.proxycare.features.caretaker.enums.KycStepState;
import com.proxycare.features.caretaker.enums.OnboardingStatus;
import com.proxycare.features.caretaker.enums.VideoVerificationStatus;
import com.proxycare.features.caretaker.exception.BasicInformationDraftNotFoundException;
import com.proxycare.features.caretaker.exception.CaretakerNotFoundException;
import com.proxycare.features.caretaker.exception.EmailAlreadyInUseException;
import com.proxycare.features.caretaker.exception.KycStepLockedException;
import com.proxycare.features.caretaker.exception.PhotoPathNotOwnedException;
import com.proxycare.features.caretaker.mapper.CaretakerMapper;
import com.proxycare.features.caretaker.repository.BankVerificationRequestRepository;
import com.proxycare.features.caretaker.repository.CaretakerRepository;
import com.proxycare.features.caretaker.repository.FileRepository;
import java.time.Clock;
import java.time.Instant;
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
    private static final int PHOTO_AND_VIDEO_KYC_STEP_NUMBER = KycStep.PHOTO_AND_VIDEO_KYC.getStepNumber();
    private static final int PAYOUT_ACCOUNT_STEP_NUMBER = KycStep.PAYOUT_ACCOUNT.getStepNumber();
    private static final String STORAGE_PATH_SEPARATOR = "/";
    private static final String PARENT_DIRECTORY = "..";
    private static final String VKYC_SLOT_AT_FIELD = "vkycSlotAt";
    private static final String VKYC_SLOT_IN_PAST_MESSAGE = "must be in the future";

    private final CaretakerRepository caretakerRepository;
    private final FileRepository fileRepository;
    private final BankVerificationRequestRepository bankVerificationRequestRepository;
    private final CaretakerMapper caretakerMapper;
    private final BasicInformationValidator basicInformationValidator;
    private final ISecurityIdentityProvider securityIdentityProvider;
    private final Clock clock;

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
        return toKycProgressResponse(findCurrentCaretakerEntity());
    }

    @Override
    @Transactional(readOnly = true)
    public CaretakerResponse getCurrentCaretaker() {
        return caretakerMapper.toCaretakerResponse(findCurrentCaretakerEntity());
    }

    // No rollback on a rejected save: the draft written first must stay committed (decision OQ-2).
    @Override
    @Transactional(noRollbackFor = {FieldValidationException.class, EmailAlreadyInUseException.class})
    public KycProgressResponse saveCurrentBasicInformation(SaveBasicInformationRequest saveBasicInformationRequest) {
        AuthenticatedUser authenticatedUser = securityIdentityProvider.getAuthenticatedUser();
        CaretakerEntity caretakerEntity = caretakerRepository.findByProfileId(authenticatedUser.userId())
                .orElseThrow(CaretakerNotFoundException::new);
        if (caretakerEntity.getOnboardingStatus() != OnboardingStatus.IN_PROGRESS) {
            throw new KycStepLockedException();
        }

        caretakerEntity.setBasicInformationDraft(caretakerMapper.toBasicInformationDraft(saveBasicInformationRequest));
        caretakerRepository.save(caretakerEntity);

        basicInformationValidator.validate(saveBasicInformationRequest, authenticatedUser.phone());
        if (caretakerRepository.existsByEmailIgnoreCaseAndIdNot(
                saveBasicInformationRequest.email(), caretakerEntity.getId())) {
            throw new EmailAlreadyInUseException();
        }

        updateBasicInformation(caretakerEntity, saveBasicInformationRequest);
        caretakerEntity.setBasicInformationDraft(null);
        caretakerEntity.setKycStep(Math.max(caretakerEntity.getKycStep(), PHOTO_AND_VIDEO_KYC_STEP_NUMBER));

        CaretakerEntity savedCaretakerEntity = caretakerRepository.save(caretakerEntity);
        return toKycProgressResponse(savedCaretakerEntity);
    }

    @Override
    @Transactional(readOnly = true)
    public BasicInformationDraftResponse getCurrentBasicInformationDraft() {
        BasicInformationDraft basicInformationDraft = findCurrentCaretakerEntity().getBasicInformationDraft();
        if (basicInformationDraft == null) {
            throw new BasicInformationDraftNotFoundException();
        }

        return caretakerMapper.toBasicInformationDraftResponse(basicInformationDraft);
    }

    @Override
    @Transactional
    public KycProgressResponse saveCurrentIdentityCheck(SaveIdentityCheckRequest saveIdentityCheckRequest) {
        CaretakerEntity caretakerEntity = findCurrentCaretakerEntity();
        boolean basicInformationDone = caretakerEntity.getKycStep() >= PHOTO_AND_VIDEO_KYC_STEP_NUMBER;
        if (!basicInformationDone || caretakerEntity.getOnboardingStatus() != OnboardingStatus.IN_PROGRESS) {
            throw new KycStepLockedException();
        }
        PhotoFileRequest photoFileRequest = saveIdentityCheckRequest.photo();
        if (!isInOwnFolder(photoFileRequest.storagePath(), caretakerEntity.getProfileId())) {
            throw new PhotoPathNotOwnedException();
        }
        requireFutureVkycSlot(saveIdentityCheckRequest.vkycSlotAt());

        FileEntity photoFileEntity = fileRepository
                .findByOwnerIdAndKind(caretakerEntity.getProfileId(), FileKind.CARETAKER_PHOTO)
                .orElseGet(() -> buildCaretakerPhotoFileEntity(caretakerEntity.getProfileId()));
        updatePhotoFile(photoFileEntity, photoFileRequest);
        FileEntity savedPhotoFileEntity = fileRepository.save(photoFileEntity);

        caretakerEntity.setPhotoFileId(savedPhotoFileEntity.getId());
        caretakerEntity.setVkycSlotAt(saveIdentityCheckRequest.vkycSlotAt());
        caretakerEntity.setKycStep(Math.max(caretakerEntity.getKycStep(), PAYOUT_ACCOUNT_STEP_NUMBER));

        CaretakerEntity savedCaretakerEntity = caretakerRepository.save(caretakerEntity);
        return toKycProgressResponse(savedCaretakerEntity);
    }

    @Override
    @Transactional
    public KycProgressResponse rebookCurrentVkycCall(VkycBookingRequest vkycBookingRequest) {
        CaretakerEntity caretakerEntity = findCurrentCaretakerEntity();
        boolean submitted = caretakerEntity.getOnboardingStatus() == OnboardingStatus.SUBMITTED;
        boolean videoPending = caretakerEntity.getVideoVerificationStatus() == VideoVerificationStatus.PENDING;
        if (!submitted || !videoPending) {
            throw new KycStepLockedException();
        }
        requireFutureVkycSlot(vkycBookingRequest.vkycSlotAt());

        caretakerEntity.setVkycSlotAt(vkycBookingRequest.vkycSlotAt());

        CaretakerEntity savedCaretakerEntity = caretakerRepository.save(caretakerEntity);
        return toKycProgressResponse(savedCaretakerEntity);
    }

    private CaretakerEntity findCurrentCaretakerEntity() {
        return caretakerRepository.findByProfileId(securityIdentityProvider.getAuthenticatedUserId())
                .orElseThrow(CaretakerNotFoundException::new);
    }

    private KycProgressResponse toKycProgressResponse(CaretakerEntity caretakerEntity) {
        boolean checklistFinished = caretakerEntity.getOnboardingStatus() != OnboardingStatus.IN_PROGRESS;
        int stepNumber = checklistFinished ? TOTAL_STEPS : caretakerEntity.getKycStep();
        List<KycStepResponse> kycStepResponses = Arrays.stream(KycStep.values())
                .map(kycStep -> new KycStepResponse(kycStep, toKycStepState(kycStep, stepNumber, checklistFinished)))
                .toList();

        return caretakerMapper.toKycProgressResponse(
                caretakerEntity, stepNumber, TOTAL_STEPS, kycStepResponses, findBankFailureReason(caretakerEntity));
    }

    private BankVerificationFailureReason findBankFailureReason(CaretakerEntity caretakerEntity) {
        if (caretakerEntity.getBankVerificationStatus() != BankVerificationStatus.FAILED) {
            return null;
        }
        return bankVerificationRequestRepository.findFirstByCaretakerIdOrderByCreatedAtDesc(caretakerEntity.getId())
                .map(BankVerificationRequestEntity::getFailureReason)
                .orElse(null);
    }

    private void requireFutureVkycSlot(Instant vkycSlotAt) {
        if (!vkycSlotAt.isAfter(clock.instant())) {
            throw new FieldValidationException(VKYC_SLOT_AT_FIELD, VKYC_SLOT_IN_PAST_MESSAGE);
        }
    }

    // The storage policy only lets the app write under <auth uid>/, so a path elsewhere is not the caller's upload.
    private static boolean isInOwnFolder(String storagePath, UUID profileId) {
        String ownFolder = profileId + STORAGE_PATH_SEPARATOR;
        return storagePath.startsWith(ownFolder)
                && storagePath.length() > ownFolder.length()
                && !storagePath.contains(PARENT_DIRECTORY);
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

    private static FileEntity buildCaretakerPhotoFileEntity(UUID profileId) {
        FileEntity fileEntity = new FileEntity();
        fileEntity.setOwnerId(profileId);
        fileEntity.setKind(FileKind.CARETAKER_PHOTO);
        return fileEntity;
    }

    private static void updateBasicInformation(
            CaretakerEntity caretakerEntity, SaveBasicInformationRequest saveBasicInformationRequest) {
        caretakerEntity.setFullName(saveBasicInformationRequest.fullName());
        caretakerEntity.setSex(saveBasicInformationRequest.sex());
        caretakerEntity.setAge(saveBasicInformationRequest.age());
        caretakerEntity.setEmail(saveBasicInformationRequest.email());
        caretakerEntity.setEmergencyContact(saveBasicInformationRequest.emergencyContact());
        caretakerEntity.setResidentialAddress(saveBasicInformationRequest.residentialAddress());
        caretakerEntity.setOccupation(saveBasicInformationRequest.occupation());
        caretakerEntity.setMaritalStatus(saveBasicInformationRequest.maritalStatus());
    }

    private static void updatePhotoFile(FileEntity fileEntity, PhotoFileRequest photoFileRequest) {
        fileEntity.setStoragePath(photoFileRequest.storagePath());
        fileEntity.setFileName(photoFileRequest.fileName());
        fileEntity.setMimeType(photoFileRequest.mimeType());
        fileEntity.setSizeBytes(photoFileRequest.sizeBytes());
    }

    private static KycStepState toKycStepState(KycStep kycStep, int currentStepNumber, boolean checklistFinished) {
        int kycStepNumber = kycStep.getStepNumber();
        if (checklistFinished || kycStepNumber < currentStepNumber) {
            return KycStepState.DONE;
        }
        return kycStepNumber == currentStepNumber ? KycStepState.CURRENT : KycStepState.TODO;
    }
}
