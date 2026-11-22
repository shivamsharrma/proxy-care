package com.proxycare.features.profile.repository;

import com.proxycare.features.profile.entity.ProfileEntity;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProfileRepository extends JpaRepository<ProfileEntity, UUID> {
}
