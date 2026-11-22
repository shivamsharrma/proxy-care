package com.proxycare.features.profile.service;

import com.proxycare.features.profile.dto.request.ProfileUpdateRequest;
import com.proxycare.features.profile.dto.response.ProfileResponse;

public interface IProfileService {
    ProfileResponse getCurrentProfile();
    ProfileResponse updateCurrentProfile(ProfileUpdateRequest profileUpdateRequest);
}
