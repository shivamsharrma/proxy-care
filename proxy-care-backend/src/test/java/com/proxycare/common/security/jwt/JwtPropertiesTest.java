package com.proxycare.common.security.jwt;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.support.IntegrationTest;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class JwtPropertiesTest extends IntegrationTest {

    @Autowired
    JwtProperties jwtProperties;

    @Test
    void derivesIssuerAndJwksFromTheProjectUrl() {
        JwtProperties props = new JwtProperties("https://abc.supabase.co", "authenticated", Duration.ofSeconds(30));

        assertThat(props.issuer()).isEqualTo("https://abc.supabase.co/auth/v1");
        assertThat(props.jwkSetUri()).isEqualTo("https://abc.supabase.co/auth/v1/.well-known/jwks.json");
    }

    @Test
    void trailingSlashIsIgnored() {
        JwtProperties props = new JwtProperties("https://abc.supabase.co/", "authenticated", Duration.ofSeconds(30));

        assertThat(props.issuer()).isEqualTo("https://abc.supabase.co/auth/v1");
    }

    @Test
    void bindsFromConfigurationWithDefaults() {
        assertThat(jwtProperties.supabaseUrl()).isEqualTo("https://test.supabase.co");
        assertThat(jwtProperties.audience()).isEqualTo("authenticated");
        assertThat(jwtProperties.clockSkew()).isEqualTo(Duration.ofSeconds(30));
    }
}
