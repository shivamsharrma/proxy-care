package com.proxycare.features.profile.mapper;

import com.proxycare.features.profile.dto.response.ProfileResponse;
import com.proxycare.features.profile.entity.ProfileEntity;
import org.mapstruct.Mapper;

@Mapper
public interface ProfileMapper {

    ProfileResponse toProfileResponse(ProfileEntity profileEntity);
}
