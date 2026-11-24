package com.proxycare.features.patient.service;

import com.proxycare.common.api.PageResponse;
import com.proxycare.features.patient.dto.request.SavePatientRequest;
import com.proxycare.features.patient.dto.response.PatientResponse;
import com.proxycare.features.patient.entity.PatientEntity;
import com.proxycare.features.patient.mapper.PatientMapper;
import com.proxycare.features.patient.repository.PatientRepository;
import com.proxycare.features.user.dto.response.AppUserReferenceResponse;
import com.proxycare.features.user.service.IAppUserService;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PatientService implements IPatientService {

    // The id breaks ties between patients added at the same instant, so pages never overlap.
    private static final Sort OLDEST_FIRST = Sort.by("createdAt", "id");

    private final PatientRepository patientRepository;
    private final PatientMapper patientMapper;
    private final IAppUserService appUserService;

    @Override
    @Transactional
    public PatientResponse createPatientForCurrentUser(SavePatientRequest savePatientRequest) {
        AppUserReferenceResponse appUserReferenceResponse = appUserService.getCurrentAppUserReference();

        PatientEntity patientEntity = buildPatientEntityForAppUser(appUserReferenceResponse.appUserId());
        applySavePatientRequest(patientEntity, savePatientRequest, appUserReferenceResponse.address());

        PatientEntity savedPatientEntity = patientRepository.save(patientEntity);
        return patientMapper.toPatientResponse(savedPatientEntity);
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PatientResponse> getCurrentUserPatients(Pageable pageable) {
        AppUserReferenceResponse appUserReferenceResponse = appUserService.getCurrentAppUserReference();
        PageRequest oldestFirstPageRequest =
                PageRequest.of(pageable.getPageNumber(), pageable.getPageSize(), OLDEST_FIRST);

        Page<PatientResponse> patientResponsePage = patientRepository
                .findByUserIdAndDeletedAtIsNull(appUserReferenceResponse.appUserId(), oldestFirstPageRequest)
                .map(patientMapper::toPatientResponse);
        return PageResponse.from(patientResponsePage);
    }

    private static PatientEntity buildPatientEntityForAppUser(UUID appUserId) {
        PatientEntity patientEntity = new PatientEntity();
        patientEntity.setUserId(appUserId);
        return patientEntity;
    }

    private static void applySavePatientRequest(
            PatientEntity patientEntity, SavePatientRequest savePatientRequest, String appUserAddress) {
        boolean livesAtUserAddress = savePatientRequest.livesAtUserAddress();
        patientEntity.setRelation(savePatientRequest.relation());
        patientEntity.setFullName(savePatientRequest.fullName());
        patientEntity.setAge(savePatientRequest.age());
        patientEntity.setSex(savePatientRequest.sex());
        patientEntity.setMobile(savePatientRequest.mobile());
        patientEntity.setLivesAtUserAddress(livesAtUserAddress);
        patientEntity.setAddress(livesAtUserAddress ? appUserAddress : savePatientRequest.address());
        patientEntity.setMobility(savePatientRequest.mobility());
        patientEntity.setHealthNotes(savePatientRequest.healthNotes());
    }
}
