package com.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Duration;
import java.util.UUID;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;
import org.springframework.beans.factory.annotation.Autowired;

@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class IntegrationTestIsolationTest extends IntegrationTest {

    @Autowired
    Clock clockBean;

    @Test
    @Order(1)
    void firstTestInsertsAndMovesTheClock() {
        db.insertAuthUser(UUID.randomUUID());
        clock.advance(Duration.ofDays(1));

        assertThat(db.count("auth.users")).isEqualTo(1);
    }

    @Test
    @Order(2)
    void secondTestStartsEmptyAtTheDefaultTime() {
        assertThat(db.count("auth.users")).isZero();
        assertThat(clock.instant()).isEqualTo(MutableClock.DEFAULT_INSTANT);
    }

    @Test
    void injectedClockIsTheMutableClock() {
        assertThat(clockBean).isSameAs(clock);
    }
}
