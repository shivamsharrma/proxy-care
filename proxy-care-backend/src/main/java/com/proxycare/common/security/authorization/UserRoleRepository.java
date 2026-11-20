package com.proxycare.common.security.authorization;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.EnumSet;
import java.util.Set;
import java.util.UUID;

/**
 * Reads a user's roles from {@code profiles.roles}, the source of truth. Read on every request (no cache
 * yet), so a role change applies on the next call instead of after the token refreshes.
 */
@Repository
public class UserRoleRepository {

    private static final String ROLES_OF_USER = "select unnest(roles)::text from profiles where id = ?";

    private final JdbcTemplate jdbc;

    public UserRoleRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Empty when the user has no profile yet (still onboarding). */
    public Set<Role> findRoles(UUID userId) {
        Set<Role> roles = EnumSet.noneOf(Role.class);
        jdbc.query(ROLES_OF_USER, row -> {
            roles.add(Role.valueOf(row.getString(1)));
        }, userId);
        return roles;
    }

}
