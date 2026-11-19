package com.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class TestDbProfileTest extends IntegrationTest {

    @Autowired
    JdbcTemplate jdbc;

    @Test
    void insertProfileCreatesAuthUserAndProfile() {
        var id = UUID.randomUUID();

        db.insertProfile(id, "+919876543210", "USER", "CARETAKER");

        assertThat(db.count("auth.users")).isEqualTo(1);
        assertThat(jdbc.queryForObject(
                        "select array_to_string(roles, ',') from profiles where id = ?", String.class, id))
                .isEqualTo("USER,CARETAKER");
    }

    @Test
    void truncateAllRemovesBoth() {
        db.insertProfile(UUID.randomUUID(), "+919876543210", "USER");

        db.truncateAll();

        assertThat(db.count("auth.users")).isZero();
        assertThat(db.count("profiles")).isZero();
    }
}
