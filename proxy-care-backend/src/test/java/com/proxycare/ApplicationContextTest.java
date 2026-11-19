package com.proxycare;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.support.TestConfig;
import javax.sql.DataSource;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
@Import(TestConfig.class)
class ApplicationContextTest {

    @Autowired
    DataSource dataSource;

    @Test
    void contextLoadsAgainstTestcontainersDatabase() {
        var version = new JdbcTemplate(dataSource).queryForObject("show server_version", String.class);
        assertThat(version).startsWith("17");
    }
}
