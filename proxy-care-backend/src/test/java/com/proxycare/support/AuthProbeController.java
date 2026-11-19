package com.proxycare.support;

import com.proxycare.common.error.AppException;
import com.proxycare.common.error.ErrorCode;
import com.proxycare.common.security.CurrentUser;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Test-only endpoints for role checks and the ownership-in-the-query rule. */
@RestController
@RequestMapping("/api/v1/_probe")
class AuthProbeController {

    private final JdbcTemplate jdbc;

    AuthProbeController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/caretaker-only")
    @PreAuthorize("hasRole('CARETAKER')")
    String caretakerOnly() {
        return "ok";
    }

    /** Ownership is part of the query; someone else's thing is simply not found (404, not 403). */
    @GetMapping("/things/{id}")
    UUID thing(@PathVariable UUID id, @AuthenticationPrincipal CurrentUser me) {
        return jdbc.query(
                        "select id from test_support.owned_things where id = ? and user_id = ?",
                        (rs, i) -> rs.getObject(1, UUID.class),
                        id,
                        me.id())
                .stream()
                .findFirst()
                .orElseThrow(() -> new AppException(ErrorCode.NOT_FOUND, "Thing not found."));
    }
}
