package com.proxycare.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

/** Constraints on the profiles table from V2__profiles.sql. */
class ProfilesConstraintTest extends IntegrationTest {

    private static final String INSERT =
            "insert into profiles (id, roles, phone, preferred_language) values (?, '{USER}', ?, ?)";

    @Autowired
    JdbcTemplate jdbc;

    @Test
    void invalidPreferredLanguageIsRejected() {
        var id = UUID.randomUUID();
        db.insertAuthUser(id);

        assertThatThrownBy(() -> jdbc.update(INSERT, id, "+919876543210", "fr"))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void validProfileInserts() {
        var id = UUID.randomUUID();
        db.insertAuthUser(id);

        jdbc.update(INSERT, id, "+919876543210", "hi");

        assertThat(db.count("profiles")).isEqualTo(1);
    }
}
