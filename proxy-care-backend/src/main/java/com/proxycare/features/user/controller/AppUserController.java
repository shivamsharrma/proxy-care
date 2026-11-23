package com.proxycare.features.user.controller;

import com.proxycare.features.user.dto.request.SaveAppUserRequest;
import com.proxycare.features.user.dto.response.AppUserResponse;
import com.proxycare.features.user.service.IAppUserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@PreAuthorize("hasRole('USER')")
public class AppUserController {

    private final IAppUserService appUserService;

    @GetMapping("/me")
    public AppUserResponse me() {
        return appUserService.getCurrentAppUser();
    }

    @PostMapping("/me")
    @ResponseStatus(HttpStatus.CREATED)
    public AppUserResponse createAppUser(@Valid @RequestBody SaveAppUserRequest saveAppUserRequest) {
        return appUserService.createCurrentAppUser(saveAppUserRequest);
    }

    @PutMapping("/me")
    public AppUserResponse updateAppUser(@Valid @RequestBody SaveAppUserRequest saveAppUserRequest) {
        return appUserService.updateCurrentAppUser(saveAppUserRequest);
    }
}
