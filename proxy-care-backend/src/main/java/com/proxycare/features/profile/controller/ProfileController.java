package com.proxycare.features.profile.controller;

import com.proxycare.features.profile.dto.response.ProfileResponse;
import com.proxycare.features.profile.service.IProfileService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/profile")
@RequiredArgsConstructor
public class ProfileController {

    private final IProfileService profileService;

    @GetMapping("/me")
    public ProfileResponse me() {
        return profileService.getCurrentProfile();
    }
}
