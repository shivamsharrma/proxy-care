package com.proxycare.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.proxycare.support.IntegrationTest;
import com.proxycare.support.MutableClock;
import java.time.Duration;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.OptimisticLockingFailureException;

class BaseEntityAuditingTest extends IntegrationTest {

    @Autowired
    AuditedThingRepository auditedThingRepository;

    @Test
    void saveSetsIdTimestampsAndVersion() {
        var saved = auditedThingRepository.save(new AuditedThing("a"));

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getCreatedAt().toInstant()).isEqualTo(MutableClock.DEFAULT_INSTANT);
        assertThat(saved.getUpdatedAt().toInstant()).isEqualTo(MutableClock.DEFAULT_INSTANT);
        assertThat(saved.getCreatedAt().getZone()).isEqualTo(ZoneOffset.UTC);
        assertThat(saved.getVersion()).isZero();
    }

    @Test
    void updateBumpsUpdatedAtAndVersion() {
        var saved = auditedThingRepository.save(new AuditedThing("a"));
        mutableClock.advance(Duration.ofMinutes(5));

        var loaded = auditedThingRepository.findById(saved.getId()).orElseThrow();
        loaded.setName("b");
        var updated = auditedThingRepository.save(loaded);

        assertThat(updated.getCreatedAt().toInstant()).isEqualTo(MutableClock.DEFAULT_INSTANT);
        assertThat(updated.getUpdatedAt().toInstant()).isEqualTo(MutableClock.DEFAULT_INSTANT.plus(Duration.ofMinutes(5)));
        assertThat(updated.getVersion()).isEqualTo(1);
    }

    @Test
    void staleVersionUpdateIsRejected() {
        var stale = auditedThingRepository.save(new AuditedThing("a"));
        var fresh = auditedThingRepository.findById(stale.getId()).orElseThrow();
        fresh.setName("b");
        auditedThingRepository.save(fresh);

        stale.setName("c");

        assertThatThrownBy(() -> auditedThingRepository.save(stale)).isInstanceOf(OptimisticLockingFailureException.class);
    }
}
