package com.proxycare.support;

import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import com.proxycare.common.security.jwt.JwtProperties;
import com.proxycare.common.security.jwt.SupabaseJwtDecoderFactory;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * Test beans. The container is a bean, not a static @Container field: Spring caches the context, so
 * every IntegrationTest class shares one container, which stops when the JVM exits.
 */
@TestConfiguration(proxyBeanMethods = false)
public class TestConfig {

    // Matches the Supabase project's Postgres major version (17).
    static final DockerImageName POSTGIS =
            DockerImageName.parse("postgis/postgis:17-3.5").asCompatibleSubstituteFor("postgres");

    @Bean
    @ServiceConnection
    PostgreSQLContainer postgres() {
        return new PostgreSQLContainer(POSTGIS);
    }

    /** The app's Clock in tests. */
    @Bean
    @Primary
    MutableClock mutableClock() {
        return new MutableClock();
    }

    @Bean
    TestTokens testTokens(MutableClock mutableClock) {
        return new TestTokens(mutableClock);
    }

    @Bean
    TestDb testDb(JdbcTemplate jdbcTemplate) {
        return new TestDb(jdbcTemplate);
    }

    /** Trusts the TestTokens keys instead of Supabase's JWKS, through the same rules as prod. */
    @Bean
    @Primary
    JwtDecoder testJwtDecoder(TestTokens testTokens, JwtProperties jwtProperties, MutableClock mutableClock) {
        return SupabaseJwtDecoderFactory.withKeys(
                new ImmutableJWKSet<>(testTokens.publicJwkSet()), jwtProperties, mutableClock);
    }
}
