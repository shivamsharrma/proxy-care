package com.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.ClassOrderer;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestClassOrder;
import org.springframework.beans.factory.annotation.Autowired;
import org.testcontainers.postgresql.PostgreSQLContainer;

/** Two test classes extending IntegrationTest see the same container (a restart would change the port). */
@TestClassOrder(ClassOrderer.OrderAnnotation.class)
class SharedContainerTest {

    static String firstJdbcUrl;

    @Nested
    @Order(1)
    class First extends IntegrationTest {

        @Autowired
        PostgreSQLContainer postgreSQLContainer;

        @Test
        void recordsJdbcUrl() {
            firstJdbcUrl = postgreSQLContainer.getJdbcUrl();
            assertThat(firstJdbcUrl).isNotBlank();
        }
    }

    @Nested
    @Order(2)
    class Second extends IntegrationTest {

        @Autowired
        PostgreSQLContainer postgreSQLContainer;

        @Test
        void seesTheSameJdbcUrl() {
            assertThat(postgreSQLContainer.getJdbcUrl()).isEqualTo(firstJdbcUrl);
        }
    }
}
