package com.proxycare.common.crypto;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/**
 * Encrypts a text column with AES-256-GCM: a random 12-byte IV per value, stored as base64(iv || ciphertext || tag).
 * Use it with {@code @Convert(converter = AesGcmStringConverter.class)}; Hibernate gets this bean from Spring. A
 * missing or wrong-length key fails startup. Neither the value nor the key ever appears in an exception message.
 */
@Converter
@Component
public class AesGcmStringConverter implements AttributeConverter<String, String> {

    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final String KEY_ALGORITHM = "AES";
    private static final int KEY_LENGTH_BYTES = 32;
    private static final int IV_LENGTH_BYTES = 12;
    private static final int TAG_LENGTH_BITS = 128;
    private static final String INVALID_KEY_MESSAGE =
            "proxycare.crypto.bank-account-encryption-key must be the base64 of a 32-byte key";
    private static final String ENCRYPT_FAILED_MESSAGE = "Could not encrypt a column value";
    private static final String DECRYPT_FAILED_MESSAGE = "Could not decrypt a column value";

    private final SecretKey secretKey;
    private final SecureRandom secureRandom = new SecureRandom();

    public AesGcmStringConverter(CryptoProperties cryptoProperties) {
        this.secretKey = toSecretKey(cryptoProperties.bankAccountEncryptionKey());
    }

    @Override
    public String convertToDatabaseColumn(String plainText) {
        if (plainText == null) {
            return null;
        }
        byte[] iv = new byte[IV_LENGTH_BYTES];
        secureRandom.nextBytes(iv);
        try {
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, new GCMParameterSpec(TAG_LENGTH_BITS, iv));
            byte[] cipherTextAndTag = cipher.doFinal(plainText.getBytes(StandardCharsets.UTF_8));
            byte[] ivAndCipherText = ByteBuffer.allocate(iv.length + cipherTextAndTag.length)
                    .put(iv)
                    .put(cipherTextAndTag)
                    .array();
            return Base64.getEncoder().encodeToString(ivAndCipherText);
        } catch (GeneralSecurityException generalSecurityException) {
            throw new IllegalStateException(ENCRYPT_FAILED_MESSAGE, generalSecurityException);
        }
    }

    @Override
    public String convertToEntityAttribute(String storedValue) {
        if (storedValue == null) {
            return null;
        }
        try {
            byte[] ivAndCipherText = Base64.getDecoder().decode(storedValue);
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.DECRYPT_MODE, secretKey,
                    new GCMParameterSpec(TAG_LENGTH_BITS, ivAndCipherText, 0, IV_LENGTH_BYTES));
            byte[] plainBytes = cipher.doFinal(
                    ivAndCipherText, IV_LENGTH_BYTES, ivAndCipherText.length - IV_LENGTH_BYTES);
            return new String(plainBytes, StandardCharsets.UTF_8);
        } catch (GeneralSecurityException | IllegalArgumentException decryptException) {
            throw new IllegalStateException(DECRYPT_FAILED_MESSAGE, decryptException);
        }
    }

    // The cause is dropped on purpose: Base64's message may echo part of the key.
    private static SecretKey toSecretKey(String base64Key) {
        byte[] keyBytes;
        try {
            keyBytes = Base64.getDecoder().decode(base64Key.trim());
        } catch (IllegalArgumentException illegalArgumentException) {
            throw new IllegalStateException(INVALID_KEY_MESSAGE);
        }
        if (keyBytes.length != KEY_LENGTH_BYTES) {
            throw new IllegalStateException(INVALID_KEY_MESSAGE);
        }
        return new SecretKeySpec(keyBytes, KEY_ALGORITHM);
    }
}
