package com.proxycare;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.support.IntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class ApplicationContextTest extends IntegrationTest {

    @Autowired
    JdbcTemplate jdbcTemplate;

    @Test
    void contextLoadsAgainstTestcontainersDatabase() {
        assertThat(jdbcTemplate.queryForObject("show server_version", String.class)).startsWith("17");
    }
}
