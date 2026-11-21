package com.proxycare.features.profile.service;

import com.proxycare.common.security.authorization.IUserRoleProvider;
import com.proxycare.common.security.authorization.Role;
import com.proxycare.features.profile.entity.ProfileEntity;
import com.proxycare.features.profile.repository.ProfileRepository;
import java.util.Set;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ProfileRoleProvider implements IUserRoleProvider {

    private final ProfileRepository profileRepository;

    @Override
    @Transactional(readOnly = true)
    public Set<Role> findRoles(UUID userId) {
        return profileRepository.findById(userId)
                .map(ProfileEntity::getRoles)
                .map(Set::copyOf)
                .orElse(Set.of());
    }
}
