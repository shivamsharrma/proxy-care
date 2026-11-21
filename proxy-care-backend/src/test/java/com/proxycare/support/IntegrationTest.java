package com.proxycare.support;

import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.ObjectMapper;

/**
 * Base class for every test that needs Spring, the database or HTTP. Subclasses must not add context
 * configuration (no @MockitoBean, no extra properties), so all of them share one cached context and
 * one container. Each test starts with empty tables and the clock at {@link MutableClock#DEFAULT_INSTANT}.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(TestConfig.class)
public abstract class IntegrationTest {

    @Autowired
    protected MockMvc mockMvc;

    @Autowired
    protected ObjectMapper objectMapper;

    @Autowired
    protected TestDb testDb;

    @Autowired
    protected MutableClock mutableClock;

    @Autowired
    protected TestTokens testTokens;

    @BeforeEach
    void resetState() {
        testDb.truncateAll();
        mutableClock.reset();
    }

    /** {@code Authorization} header value with a valid token for the user. */
    protected String bearer(UUID userId) {
        return "Bearer " + testTokens.forUser(userId, "+919876543210");
    }
}
