package com.proxycare.features.caretaker.repository;

import com.proxycare.features.caretaker.entity.FileEntity;
import com.proxycare.features.caretaker.enums.FileKind;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FileRepository extends JpaRepository<FileEntity, UUID> {

    Optional<FileEntity> findByOwnerIdAndKind(UUID ownerId, FileKind kind);
}
