package com.proxycare.common.idempotency;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.support.IntegrationTest;
import java.sql.Timestamp;
import java.time.Duration;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class IdempotencyCleanupTest extends IntegrationTest {

    @Autowired
    IdempotencyService idempotency;

    @Autowired
    JdbcTemplate jdbc;

    @Test
    void deletesKeysOlderThan24Hours() {
        insertKeyCreatedAgo(Duration.ofHours(25));
        var fresh = insertKeyCreatedAgo(Duration.ofHours(23));

        idempotency.deleteExpired();

        assertThat(jdbc.queryForList("select key from idempotency_keys", UUID.class)).containsExactly(fresh);
    }

    private UUID insertKeyCreatedAgo(Duration age) {
        var key = UUID.randomUUID();
        jdbc.update(
                "insert into idempotency_keys (user_id, key, request_hash, created_at) values (?, ?, 'h', ?)",
                UUID.randomUUID(),
                key,
                Timestamp.from(clock.instant().minus(age)));
        return key;
    }
}
