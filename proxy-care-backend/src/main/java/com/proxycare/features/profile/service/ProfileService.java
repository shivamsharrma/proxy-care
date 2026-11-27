package com.proxycare.features.profile.service;

import com.proxycare.common.security.authorization.Role;
import com.proxycare.common.security.identity.AuthenticatedUser;
import com.proxycare.common.security.identity.ISecurityIdentityProvider;
import com.proxycare.features.caretaker.service.ICaretakerService;
import com.proxycare.features.profile.dto.request.ProfileUpdateRequest;
import com.proxycare.features.profile.dto.response.ProfileResponse;
import com.proxycare.features.profile.entity.ProfileEntity;
import com.proxycare.features.profile.exception.AdminRoleNotSelfAssignableException;
import com.proxycare.features.profile.exception.ProfileNotFoundException;
import com.proxycare.features.profile.mapper.ProfileMapper;
import com.proxycare.features.profile.repository.ProfileRepository;
import java.util.LinkedHashSet;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ProfileService implements IProfileService {

    private static final String E164_PREFIX = "+";

    private final ProfileRepository profileRepository;
    private final ProfileMapper profileMapper;
    private final ISecurityIdentityProvider securityIdentityProvider;
    private final ICaretakerService caretakerService;

    @Override
    @Transactional(readOnly = true)
    public ProfileResponse getCurrentProfile() {
        return profileRepository.findById(securityIdentityProvider.getAuthenticatedUserId())
                .map(profileMapper::toProfileResponse)
                .orElseThrow(ProfileNotFoundException::new);
    }

    @Override
    @Transactional
    public ProfileResponse updateCurrentProfile(ProfileUpdateRequest profileUpdateRequest) {
        Role role = profileUpdateRequest.role();
        if (role == Role.ADMIN) {
            throw new AdminRoleNotSelfAssignableException();
        }

        AuthenticatedUser authenticatedUser = securityIdentityProvider.getAuthenticatedUser();
        ProfileEntity profileEntity = profileRepository.findById(authenticatedUser.userId())
                .orElseGet(() -> buildProfileEntityWithoutRoles(authenticatedUser));

        // A new set rather than add(): Hibernate only sees the array column change when the set is replaced.
        Set<Role> roles = new LinkedHashSet<>(profileEntity.getRoles());
        roles.add(role);
        profileEntity.setRoles(roles);
        profileEntity.setPreferredLanguage(profileUpdateRequest.preferredLanguage());

        ProfileEntity savedProfileEntity = profileRepository.save(profileEntity);
        if (role == Role.CARETAKER) {
            caretakerService.ensureCurrentCaretaker();
        }
        return profileMapper.toProfileResponse(savedProfileEntity);
    }

    private static ProfileEntity buildProfileEntityWithoutRoles(AuthenticatedUser authenticatedUser) {
        ProfileEntity profileEntity = new ProfileEntity();
        profileEntity.setId(authenticatedUser.userId());
        profileEntity.setPhone(toE164Phone(authenticatedUser.phone()));
        profileEntity.setRoles(Set.of());
        return profileEntity;
    }

    /** Supabase's phone claim may lack the leading +, e.g. 919876543210; profiles store E.164, +919876543210. */
    private static String toE164Phone(String phoneClaim) {
        return phoneClaim.startsWith(E164_PREFIX) ? phoneClaim : E164_PREFIX + phoneClaim;
    }
}
