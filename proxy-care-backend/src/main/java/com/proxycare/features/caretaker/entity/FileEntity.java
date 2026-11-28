package com.proxycare.features.caretaker.entity;

import com.proxycare.common.persistence.BaseEntity;
import com.proxycare.features.caretaker.enums.FileKind;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * A file the app uploaded to Supabase Storage; only the record lives here. The caretaker photo is the only kind
 * so far, so the caretaker feature owns the table until a second feature needs files.
 */
@Entity
@Table(name = "files")
@Getter
@Setter
@NoArgsConstructor
public class FileEntity extends BaseEntity {

    @Column(nullable = false, updatable = false)
    private UUID ownerId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private FileKind kind;

    @Column(nullable = false)
    private String fileName;

    @Column(nullable = false)
    private String mimeType;

    @Column(nullable = false)
    private Integer sizeBytes;

    @Column(nullable = false, unique = true)
    private String storagePath;
}
