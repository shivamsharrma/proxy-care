package com.proxycare.features.caretaker.repository;

import com.proxycare.features.caretaker.entity.CaretakerEntity;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CaretakerRepository extends JpaRepository<CaretakerEntity, UUID> {

    Optional<CaretakerEntity> findByProfileId(UUID profileId);

    boolean existsByProfileId(UUID profileId);
}
