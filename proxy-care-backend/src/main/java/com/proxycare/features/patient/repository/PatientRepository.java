package com.proxycare.features.patient.repository;

import com.proxycare.features.patient.entity.PatientEntity;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientRepository extends JpaRepository<PatientEntity, UUID> {

    Page<PatientEntity> findByUserIdAndDeletedAtIsNull(UUID userId, Pageable pageable);
}
