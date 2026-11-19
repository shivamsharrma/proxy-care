package com.proxycare.support;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;
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
    TestTokens testTokens(MutableClock clock) {
        return new TestTokens(clock);
    }

    @Bean
    TestDb testDb(JdbcTemplate jdbc) {
        return new TestDb(jdbc);
    }

    // M4: override JwtDecoder here with
    // NimbusJwtDecoder.withJwkSource(new ImmutableJWKSet<>(tokens.publicJwkSet())), configured by the
    // same static algorithms + validators method as prod, using the MutableClock.
}
