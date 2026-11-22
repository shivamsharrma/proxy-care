package com.proxycare.support;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.logging.MdcKeys;
import com.proxycare.common.security.authorization.Role;
import com.proxycare.common.security.identity.AuthenticatedUser;
import com.proxycare.common.security.identity.ISecurityIdentityProvider;
import java.util.UUID;
import org.slf4j.MDC;
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

    record WhoAmI(UUID userId, boolean caretaker) {}

    private final JdbcTemplate jdbcTemplate;
    private final ISecurityIdentityProvider securityIdentityProvider;

    AuthProbeController(JdbcTemplate jdbcTemplate, ISecurityIdentityProvider securityIdentityProvider) {
        this.jdbcTemplate = jdbcTemplate;
        this.securityIdentityProvider = securityIdentityProvider;
    }

    /** The caller as a service sees it, through ISecurityIdentityProvider. */
    @GetMapping("/whoami")
    WhoAmI whoami() {
        return new WhoAmI(
                securityIdentityProvider.getAuthenticatedUserId(),
                securityIdentityProvider.hasRole(Role.CARETAKER));
    }

    /** The user ID that log lines written in a controller carry. */
    @GetMapping("/log-user-id")
    String logUserId() {
        return MDC.get(MdcKeys.USER_ID);
    }

    @GetMapping("/caretaker-only")
    @PreAuthorize("hasRole('CARETAKER')")
    String caretakerOnly() {
        return "ok";
    }

    /** Ownership is part of the query; someone else's thing is simply not found (404, not 403). */
    @GetMapping("/things/{id}")
    UUID thing(@PathVariable UUID id, @AuthenticationPrincipal AuthenticatedUser authenticatedUser) {
        return jdbcTemplate.query(
                        "select id from test_support.owned_things where id = ? and user_id = ?",
                        (rs, i) -> rs.getObject(1, UUID.class),
                        id,
                        authenticatedUser.userId())
                .stream()
                .findFirst()
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND, "Thing not found."));
    }
}
