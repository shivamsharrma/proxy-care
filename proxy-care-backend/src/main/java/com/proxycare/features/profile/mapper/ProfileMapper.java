package com.proxycare.features.profile.mapper;

import com.proxycare.features.profile.dto.response.ProfileResponse;
import com.proxycare.features.profile.entity.ProfileEntity;
import org.springframework.stereotype.Component;

@Component
public class ProfileMapper {

    public ProfileResponse toProfileResponse(ProfileEntity profileEntity) {
        return new ProfileResponse(
                profileEntity.getId(),
                profileEntity.getPhone(),
                profileEntity.getRoles(),
                profileEntity.getPreferredLanguage());
    }
}
