package com.proxycare.features.user.repository;

import com.proxycare.features.user.entity.AppUserEntity;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AppUserRepository extends JpaRepository<AppUserEntity, UUID> {

    Optional<AppUserEntity> findByProfileId(UUID profileId);

    boolean existsByProfileId(UUID profileId);
}
