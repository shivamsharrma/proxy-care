package com.proxycare.common.crypto;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * {@code proxycare.crypto.*}: keys for columns encrypted at rest.
 *
 * @param bankAccountEncryptionKey base64 of a 32-byte AES-256 key (env {@code BANK_ACCOUNT_ENCRYPTION_KEY})
 */
@Validated
@ConfigurationProperties("proxycare.crypto")
public record CryptoProperties(@NotBlank String bankAccountEncryptionKey) {}
