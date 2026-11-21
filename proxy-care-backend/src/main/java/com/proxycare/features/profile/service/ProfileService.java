package com.proxycare.features.profile.service;

import com.proxycare.common.security.identity.ISecurityIdentityProvider;
import com.proxycare.features.profile.dto.response.ProfileResponse;
import com.proxycare.features.profile.exception.ProfileNotFoundException;
import com.proxycare.features.profile.mapper.ProfileMapper;
import com.proxycare.features.profile.repository.ProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ProfileService implements IProfileService {

    private final ProfileRepository profileRepository;
    private final ProfileMapper profileMapper;
    private final ISecurityIdentityProvider securityIdentityProvider;

    @Override
    @Transactional(readOnly = true)
    public ProfileResponse getCurrentProfile() {
        return profileRepository.findById(securityIdentityProvider.requireCurrentUserId())
                .map(profileMapper::toProfileResponse)
                .orElseThrow(ProfileNotFoundException::new);
    }
}
