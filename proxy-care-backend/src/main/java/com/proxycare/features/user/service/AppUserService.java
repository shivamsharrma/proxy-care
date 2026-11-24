package com.proxycare.features.user.service;

import com.proxycare.features.profile.dto.response.ProfileResponse;
import com.proxycare.features.profile.service.IProfileService;
import com.proxycare.features.user.dto.request.SaveAppUserRequest;
import com.proxycare.features.user.dto.response.AppUserReferenceResponse;
import com.proxycare.features.user.dto.response.AppUserResponse;
import com.proxycare.features.user.entity.AppUserEntity;
import com.proxycare.features.user.exception.AppUserAlreadyExistsException;
import com.proxycare.features.user.exception.AppUserNotFoundException;
import com.proxycare.features.user.mapper.AppUserMapper;
import com.proxycare.features.user.repository.AppUserRepository;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AppUserService implements IAppUserService {

    private final AppUserRepository appUserRepository;
    private final AppUserMapper appUserMapper;
    private final IProfileService profileService;

    @Override
    @Transactional(readOnly = true)
    public AppUserResponse getCurrentAppUser() {
        ProfileResponse profileResponse = profileService.getCurrentProfile();
        AppUserEntity appUserEntity = appUserRepository.findByProfileId(profileResponse.id())
                .orElseThrow(AppUserNotFoundException::new);
        return appUserMapper.toAppUserResponse(appUserEntity, profileResponse.phone());
    }

    @Override
    @Transactional
    public AppUserResponse createCurrentAppUser(SaveAppUserRequest saveAppUserRequest) {
        ProfileResponse profileResponse = profileService.getCurrentProfile();
        if (appUserRepository.existsByProfileId(profileResponse.id())) {
            throw new AppUserAlreadyExistsException();
        }

        AppUserEntity appUserEntity = buildAppUserEntityForProfile(profileResponse.id());
        applySaveAppUserRequest(appUserEntity, saveAppUserRequest);

        AppUserEntity savedAppUserEntity = appUserRepository.save(appUserEntity);
        return appUserMapper.toAppUserResponse(savedAppUserEntity, profileResponse.phone());
    }

    @Override
    @Transactional
    public AppUserResponse updateCurrentAppUser(SaveAppUserRequest saveAppUserRequest) {
        ProfileResponse profileResponse = profileService.getCurrentProfile();
        AppUserEntity appUserEntity = appUserRepository.findByProfileId(profileResponse.id())
                .orElseThrow(AppUserNotFoundException::new);
        applySaveAppUserRequest(appUserEntity, saveAppUserRequest);

        AppUserEntity savedAppUserEntity = appUserRepository.save(appUserEntity);
        return appUserMapper.toAppUserResponse(savedAppUserEntity, profileResponse.phone());
    }

    @Override
    @Transactional(readOnly = true)
    public AppUserReferenceResponse getCurrentAppUserReference() {
        ProfileResponse profileResponse = profileService.getCurrentProfile();
        AppUserEntity appUserEntity = appUserRepository.findByProfileId(profileResponse.id())
                .orElseThrow(AppUserNotFoundException::new);
        return appUserMapper.toAppUserReferenceResponse(appUserEntity);
    }

    private static AppUserEntity buildAppUserEntityForProfile(UUID profileId) {
        AppUserEntity appUserEntity = new AppUserEntity();
        appUserEntity.setProfileId(profileId);
        return appUserEntity;
    }

    private static void applySaveAppUserRequest(AppUserEntity appUserEntity, SaveAppUserRequest saveAppUserRequest) {
        appUserEntity.setFullName(saveAppUserRequest.fullName());
        appUserEntity.setSex(saveAppUserRequest.sex());
        appUserEntity.setAge(saveAppUserRequest.age());
        appUserEntity.setAddress(saveAppUserRequest.address());
    }
}
