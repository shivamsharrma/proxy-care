package com.proxycare.common.security;

import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/** HMAC-SHA256 webhook signatures (Razorpay; Uber and RazorpayX use the same scheme). */
public final class WebhookSignatures {

    private WebhookSignatures() {}

    /** Lowercase hex HMAC-SHA256 of the exact raw body bytes. */
    public static String hmacSha256Hex(byte[] rawBody, String secret) {
        try {
            var mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(rawBody));
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new IllegalStateException(e);
        }
    }

    /** Constant-time comparison; a null or blank signature (or secret) never verifies. */
    public static boolean verify(byte[] rawBody, String secret, String signatureHeader) {
        if (signatureHeader == null || signatureHeader.isBlank() || secret == null || secret.isBlank()) {
            return false;
        }
        byte[] expected = hmacSha256Hex(rawBody, secret).getBytes(StandardCharsets.US_ASCII);
        return MessageDigest.isEqual(expected, signatureHeader.trim().getBytes(StandardCharsets.UTF_8));
    }
}
