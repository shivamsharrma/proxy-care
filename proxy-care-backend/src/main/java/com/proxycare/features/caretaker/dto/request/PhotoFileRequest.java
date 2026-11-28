package com.proxycare.features.caretaker.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/** The photo the app uploaded to the caretaker-photos bucket, under {@code <user id>/}. */
public record PhotoFileRequest(
        @NotBlank @Size(max = 500) String storagePath,
        @NotBlank @Size(max = 255) String fileName,
        // A MIME type, not an enum: the wire values (image/jpeg) can't be Java enum names.
        @NotNull @Pattern(regexp = "image/jpeg|image/png", message = "must be image/jpeg or image/png") String mimeType,
        @NotNull @Positive @Max(PhotoFileRequest.MAX_SIZE_BYTES) Integer sizeBytes
) {

    static final int MAX_SIZE_BYTES = 10 * 1024 * 1024;
}
