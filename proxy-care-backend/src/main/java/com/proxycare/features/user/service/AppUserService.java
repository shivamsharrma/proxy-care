package com.proxycare.features.user.service;

import com.proxycare.features.profile.dto.response.ProfileResponse;
import com.proxycare.features.profile.service.IProfileService;
import com.proxycare.features.user.dto.request.SaveAppUserRequest;
import com.proxycare.features.user.dto.request.SavePatientRequest;
import com.proxycare.features.user.dto.response.AppUserResponse;
import com.proxycare.features.user.entity.AppUserEntity;
import com.proxycare.features.user.entity.PatientEntity;
import com.proxycare.features.user.exception.AppUserAlreadyExistsException;
import com.proxycare.features.user.exception.AppUserNotFoundException;
import com.proxycare.features.user.exception.PatientNotFoundException;
import com.proxycare.features.user.mapper.AppUserMapper;
import com.proxycare.features.user.repository.AppUserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AppUserService implements IAppUserService {

    private final AppUserRepository appUserRepository;
    private final AppUserMapper appUserMapper;
    private final IProfileService profileService;

    private static AppUserEntity buildAppUserEntityForProfile(UUID profileId) {
        AppUserEntity appUserEntity = new AppUserEntity();
        appUserEntity.setProfileId(profileId);
        return appUserEntity;
    }

    private static void updateAppUserInformation(AppUserEntity appUserEntity, SaveAppUserRequest saveAppUserRequest) {
        appUserEntity.setFullName(saveAppUserRequest.fullName());
        appUserEntity.setSex(saveAppUserRequest.sex());
        appUserEntity.setAge(saveAppUserRequest.age());
        appUserEntity.setAddress(saveAppUserRequest.address());
    }

    private static void updatePatientInformation(PatientEntity patientEntity, SavePatientRequest savePatientRequest) {

        patientEntity.setRelation(savePatientRequest.relation());
        patientEntity.setFullName(savePatientRequest.fullName());
        patientEntity.setAge(savePatientRequest.age());
        patientEntity.setSex(savePatientRequest.sex());
        patientEntity.setMobile(savePatientRequest.mobile());
        patientEntity.setAddress(savePatientRequest.address());
        patientEntity.setMobilityCategory(savePatientRequest.mobilityCategory());
        patientEntity.setHealthNotes(savePatientRequest.healthNotes());
    }

    private static Set<UUID> listedPatientIdsOf(List<SavePatientRequest> savePatientRequests) {
        return savePatientRequests.stream()
                .map(SavePatientRequest::id)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
    }

    @Override
    @Transactional(readOnly = true)
    public AppUserResponse getCurrentAppUser() {
        ProfileResponse profileResponse = profileService.getCurrentProfile();

        AppUserEntity appUserEntity = appUserRepository.findByProfileId(profileResponse.id())
                .orElseThrow(AppUserNotFoundException::new);

        return appUserMapper.toAppUserResponse(appUserEntity);
    }

    @Override
    @Transactional
    public AppUserResponse createCurrentAppUser(SaveAppUserRequest saveAppUserRequest) {
        ProfileResponse profileResponse = profileService.getCurrentProfile();

        if (appUserRepository.existsByProfileId(profileResponse.id())) {
            throw new AppUserAlreadyExistsException();
        }

        AppUserEntity appUserEntity = buildAppUserEntityForProfile(profileResponse.id());

        updateAppUserInformation(appUserEntity, saveAppUserRequest);
        updatePatientList(appUserEntity, saveAppUserRequest.patients());

        AppUserEntity savedAppUserEntity = appUserRepository.save(appUserEntity);

        return appUserMapper.toAppUserResponse(savedAppUserEntity);
    }

    @Override
    @Transactional
    public AppUserResponse updateCurrentAppUser(SaveAppUserRequest saveAppUserRequest) {
        ProfileResponse profileResponse = profileService.getCurrentProfile();

        AppUserEntity appUserEntity = appUserRepository.findByProfileId(profileResponse.id())
                .orElseThrow(AppUserNotFoundException::new);

        updateAppUserInformation(appUserEntity, saveAppUserRequest);
        updatePatientList(appUserEntity, saveAppUserRequest.patients());

        AppUserEntity savedAppUserEntity = appUserRepository.save(appUserEntity);

        return appUserMapper.toAppUserResponse(savedAppUserEntity);
    }

    // Synchronizes the managed patient collection without replacing its instance.
    private void updatePatientList(AppUserEntity appUserEntity, List<SavePatientRequest> savePatientRequests) {

        List<PatientEntity> livePatients = appUserEntity.getPatients();

        Map<UUID, PatientEntity> livePatientsById = livePatients.stream()
                .collect(Collectors.toMap(PatientEntity::getId, Function.identity()));

        Set<UUID> requestedPatientIds = listedPatientIdsOf(savePatientRequests);

        // Existing patient IDs must belong to the current user.
        if (!livePatientsById.keySet().containsAll(requestedPatientIds)) {
            throw new PatientNotFoundException();
        }

        // Patients omitted from the request are removed (soft-deleted by Hibernate).
        livePatients.removeIf(patient -> !requestedPatientIds.contains(patient.getId()));

        // Update existing patients and create new patients.
        for (SavePatientRequest request : savePatientRequests) {
            if (request.id() == null) {
                livePatients.add(appUserMapper.toPatientEntity(request));
            } else {
                updatePatientInformation(livePatientsById.get(request.id()), request);
            }
        }
    }
}
