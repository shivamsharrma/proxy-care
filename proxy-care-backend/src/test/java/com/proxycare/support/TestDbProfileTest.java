package com.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class TestDbProfileTest extends IntegrationTest {

    @Autowired
    JdbcTemplate jdbcTemplate;

    @Test
    void insertProfileCreatesAuthUserAndProfile() {
        UUID id = UUID.randomUUID();

        testDb.insertProfile(id, "+919876543210", "USER", "CARETAKER");

        assertThat(testDb.count("auth.users")).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                        "select array_to_string(roles, ',') from profiles where id = ?", String.class, id))
                .isEqualTo("USER,CARETAKER");
    }

    @Test
    void truncateAllRemovesBoth() {
        testDb.insertProfile(UUID.randomUUID(), "+919876543210", "USER");

        testDb.truncateAll();

        assertThat(testDb.count("auth.users")).isZero();
        assertThat(testDb.count("profiles")).isZero();
    }
}
