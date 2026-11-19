package com.proxycare.common.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.Test;

class WebhookSignaturesTest {

    private static final String SECRET = "whsec-test";
    private static final byte[] BODY = "{\"event\":\"payment.captured\"}".getBytes(StandardCharsets.UTF_8);

    /** Computed independently of the class under test. */
    private static String expectedHmac(byte[] body, String secret) throws Exception {
        var mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        return HexFormat.of().formatHex(mac.doFinal(body));
    }

    @Test
    void knownVectorVerifies() throws Exception {
        var signature = expectedHmac(BODY, SECRET);

        assertThat(WebhookSignatures.hmacSha256Hex(BODY, SECRET)).isEqualTo(signature);
        assertThat(WebhookSignatures.verify(BODY, SECRET, signature)).isTrue();
    }

    @Test
    void tamperedBodyFails() throws Exception {
        var signature = expectedHmac(BODY, SECRET);
        var tampered = "{\"event\":\"payment.failed\"}".getBytes(StandardCharsets.UTF_8);

        assertThat(WebhookSignatures.verify(tampered, SECRET, signature)).isFalse();
    }

    @Test
    void wrongSecretFails() throws Exception {
        assertThat(WebhookSignatures.verify(BODY, "other-secret", expectedHmac(BODY, SECRET))).isFalse();
    }

    @Test
    void nullOrBlankSignatureFails() {
        assertThat(WebhookSignatures.verify(BODY, SECRET, null)).isFalse();
        assertThat(WebhookSignatures.verify(BODY, SECRET, "")).isFalse();
        assertThat(WebhookSignatures.verify(BODY, SECRET, "   ")).isFalse();
    }
}
