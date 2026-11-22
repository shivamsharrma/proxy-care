package com.proxycare.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

/** Constraints on the profiles table from V2__profiles.sql. */
class ProfilesConstraintTest extends IntegrationTest {

    private static final String INSERT =
            "insert into profiles (id, roles, phone, preferred_language) values (?, '{USER}', ?, ?)";

    @Autowired
    JdbcTemplate jdbcTemplate;

    @Test
    void validProfileInserts() {
        UUID id = UUID.randomUUID();
        testDb.insertAuthUser(id);

        jdbcTemplate.update(INSERT, id, "+919876543210", "HI");

        assertThat(testDb.count("profiles")).isEqualTo(1);
    }
}
