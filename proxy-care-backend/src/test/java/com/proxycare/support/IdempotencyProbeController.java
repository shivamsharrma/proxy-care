package com.proxycare.support;

import com.proxycare.common.idempotency.IdempotencyService;
import com.proxycare.common.security.CurrentUser;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

/**
 * Test-only idempotent endpoint. Its action inserts a row, so "exactly once" is counted in the DB and
 * rolled back with the transaction. {@code fail} throws after the insert; {@code block} waits on
 * {@link ProbeGate} so a test can hold the transaction open without sleeping.
 */
@RestController
class IdempotencyProbeController {

    record ProbeRequest(String name, Boolean fail, Boolean block) {}

    record ProbeResult(UUID id, String name) {}

    private final IdempotencyService idempotency;
    private final JdbcTemplate jdbc;

    IdempotencyProbeController(IdempotencyService idempotency, JdbcTemplate jdbc) {
        this.idempotency = idempotency;
        this.jdbc = jdbc;
    }

    @PostMapping("/api/v1/_probe/idempotent")
    ResponseEntity<ProbeResult> create(
            @RequestHeader("Idempotency-Key") String key,
            @RequestBody ProbeRequest request,
            @AuthenticationPrincipal CurrentUser me) {
        return idempotency.execute(me.id(), key, request, ProbeResult.class, () -> {
            UUID id = jdbc.queryForObject(
                    "insert into test_support.idempotent_actions (name) values (?) returning id",
                    UUID.class,
                    request.name());
            if (Boolean.TRUE.equals(request.fail())) {
                throw new IllegalStateException("probe action failed");
            }
            if (Boolean.TRUE.equals(request.block())) {
                ProbeGate.pass();
            }
            return ResponseEntity.status(HttpStatus.CREATED).body(new ProbeResult(id, request.name()));
        });
    }
}
