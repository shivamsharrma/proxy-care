package com.proxycare.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.proxycare.support.IntegrationTest;
import com.proxycare.support.MutableClock;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.OptimisticLockingFailureException;

class BaseEntityAuditingTest extends IntegrationTest {

    @Autowired
    AuditedThingRepository repo;

    @Test
    void saveSetsIdTimestampsAndVersion() {
        var saved = repo.save(new AuditedThing("a"));

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getCreatedAt()).isEqualTo(MutableClock.DEFAULT_INSTANT);
        assertThat(saved.getUpdatedAt()).isEqualTo(MutableClock.DEFAULT_INSTANT);
        assertThat(saved.getVersion()).isZero();
    }

    @Test
    void updateBumpsUpdatedAtAndVersion() {
        var saved = repo.save(new AuditedThing("a"));
        clock.advance(Duration.ofMinutes(5));

        var loaded = repo.findById(saved.getId()).orElseThrow();
        loaded.setName("b");
        var updated = repo.save(loaded);

        assertThat(updated.getCreatedAt()).isEqualTo(MutableClock.DEFAULT_INSTANT);
        assertThat(updated.getUpdatedAt()).isEqualTo(MutableClock.DEFAULT_INSTANT.plus(Duration.ofMinutes(5)));
        assertThat(updated.getVersion()).isEqualTo(1);
    }

    @Test
    void staleVersionUpdateIsRejected() {
        var stale = repo.save(new AuditedThing("a"));
        var fresh = repo.findById(stale.getId()).orElseThrow();
        fresh.setName("b");
        repo.save(fresh);

        stale.setName("c");

        assertThatThrownBy(() -> repo.save(stale)).isInstanceOf(OptimisticLockingFailureException.class);
    }
}
