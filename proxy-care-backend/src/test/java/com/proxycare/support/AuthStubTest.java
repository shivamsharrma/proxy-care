package com.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;
import org.junit.jupiter.api.Test;

class AuthStubTest extends IntegrationTest {

    @Test
    void authUsersTableExistsAndAcceptsInsert() {
        testDb.insertAuthUser(UUID.randomUUID());

        assertThat(testDb.count("auth.users")).isEqualTo(1);
    }
}
