package com.proxycare.common.security.jwt;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

/**
 * {@code proxycare.security.jwt.*}: how Supabase access tokens are verified.
 *
 * @param supabaseUrl project URL, e.g. {@code https://abc.supabase.co}; gives the issuer and JWKS location
 * @param audience    required {@code aud} value; Supabase uses {@code authenticated} for signed-in users
 * @param clockSkew   tolerance on {@code exp} and {@code nbf}
 */
@Validated
@ConfigurationProperties("proxycare.security.jwt")
public record JwtProperties(
        @NotBlank String supabaseUrl,
        @DefaultValue("authenticated") @NotBlank String audience,
        @DefaultValue("30s") Duration clockSkew
) {

    private static final String AUTH_PATH = "/auth/v1";
    private static final String JWKS_PATH = "/.well-known/jwks.json";

    /** Supabase Auth's base URL, which is also the {@code iss} of every token it signs. */
    public String issuer() {
        return withoutTrailingSlash(supabaseUrl) + AUTH_PATH;
    }

    public String jwkSetUri() {
        return issuer() + JWKS_PATH;
    }

    private static String withoutTrailingSlash(String url) {
        return url.endsWith("/") ? url.substring(0, url.length() - 1) : url;
    }

}
