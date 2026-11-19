package com.proxycare.support;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/** Test beans: one PostGIS container for the whole test JVM, shared through Spring's context cache. */
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
}
