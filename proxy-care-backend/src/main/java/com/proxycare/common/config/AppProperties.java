package com.proxycare.common.config;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.time.Duration;
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
        @Valid @DefaultValue Supabase supabase,
        @DefaultValue Razorpay razorpay,
        @DefaultValue Google google,
        @DefaultValue Uber uber,
        @DefaultValue Idempotency idempotency) {

    /**
     * {@code url} (e.g. https://abc.supabase.co) gives the token issuer and JWKS location.
     * {@code jwtSecret} is optional: when set, legacy HS256 tokens are used instead of JWKS.
     */
    public record Supabase(@NotBlank String url, String jwtSecret) {}

    public record Razorpay(String keyId, String keySecret, String webhookSecret) {}

    public record Google(String mapsApiKey) {}

    public record Uber(String clientId, String clientSecret) {}

    /** {@code lockTimeout}: how long a duplicate request waits for the first one before getting 409. */
    public record Idempotency(@DefaultValue("3s") Duration lockTimeout) {}
}
