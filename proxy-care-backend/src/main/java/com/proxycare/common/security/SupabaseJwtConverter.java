package com.proxycare.common.security;

import com.proxycare.common.security.CurrentUser.Role;
import java.util.EnumSet;
import java.util.Set;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.core.convert.converter.Converter;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.web.authentication.preauth.PreAuthenticatedAuthenticationToken;
import org.springframework.stereotype.Component;

/**
 * Turns a verified Supabase access token into an authentication whose principal is {@link CurrentUser}.
 * Roles come from {@code profiles} on every request (no cache yet); a user without a profile is
 * authenticated with no roles.
 */
@Component
public class SupabaseJwtConverter implements Converter<Jwt, PreAuthenticatedAuthenticationToken> {

    private final JdbcTemplate jdbc;

    public SupabaseJwtConverter(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public PreAuthenticatedAuthenticationToken convert(Jwt jwt) {
        UUID id = UUID.fromString(jwt.getSubject());
        MDC.put("userId", id.toString());
        return authentication(jwt, loadRoles(id));
    }

    static PreAuthenticatedAuthenticationToken authentication(Jwt jwt, Set<Role> roles) {
        var user = new CurrentUser(UUID.fromString(jwt.getSubject()), jwt.getClaimAsString("phone"), roles);
        var authorities = roles.stream().map(r -> new SimpleGrantedAuthority("ROLE_" + r.name())).toList();
        return new PreAuthenticatedAuthenticationToken(user, jwt, authorities);
    }

    private Set<Role> loadRoles(UUID id) {
        var roles = EnumSet.noneOf(Role.class);
        jdbc.query(
                "select unnest(roles)::text from profiles where id = ?",
                rs -> {
                    roles.add(Role.valueOf(rs.getString(1)));
                },
                id);
        return roles;
    }
}
