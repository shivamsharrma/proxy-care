package com.proxycare.me;

import com.proxycare.common.logging.Mask;
import com.proxycare.common.security.CurrentUser;
import com.proxycare.common.security.CurrentUser.Role;
import java.util.Set;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * The apps call this right after login: no roles (and no preferredLanguage) means the user still has
 * to onboard. Small enough to read the one column with JdbcTemplate instead of a full feature package.
 */
@RestController
class MeController {

    record MeResponse(UUID id, String phone, Set<Role> roles, String preferredLanguage) {}

    private final JdbcTemplate jdbc;

    MeController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/api/v1/me")
    MeResponse me(@AuthenticationPrincipal CurrentUser me) {
        String language = jdbc.query(
                        "select preferred_language from profiles where id = ?",
                        (rs, i) -> rs.getString(1),
                        me.id())
                .stream()
                .findFirst()
                .orElse(null);
        return new MeResponse(me.id(), Mask.phone(me.phone()), me.roles(), language);
    }
}
