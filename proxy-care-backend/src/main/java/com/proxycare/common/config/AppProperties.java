package com.proxycare.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;
import org.springframework.validation.annotation.Validated;

/**
 * All {@code proxycare.*} settings. Only values the app needs to run are {@code @NotBlank};
 * vendor keys stay optional until their feature is built.
 */
@Validated
@ConfigurationProperties("proxycare")
public record AppProperties(
        @DefaultValue Supabase supabase,
        @DefaultValue Razorpay razorpay,
        @DefaultValue Google google,
        @DefaultValue Uber uber) {

    /** {@code jwtSecret} is optional: when set, legacy HS256 tokens are used instead of JWKS. */
    public record Supabase(String url, String jwtSecret) {}

    public record Razorpay(String keyId, String keySecret, String webhookSecret) {}

    public record Google(String mapsApiKey) {}

    public record Uber(String clientId, String clientSecret) {}
}
