package com.proxycare.common.security.jwt;

import com.proxycare.common.security.authorization.Role;
import com.proxycare.common.security.authorization.UserRoleRepository;
import com.proxycare.common.security.identity.AuthenticatedPrincipal;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Turns a verified Supabase token into an authentication whose principal is {@link AuthenticatedPrincipal}:
 * identity from the token, roles from {@link UserRoleRepository}.
 */
@Component
public class SupabaseJwtAuthenticationConverter implements Converter<Jwt, AbstractAuthenticationToken> {

    static final String PHONE_CLAIM = "phone";

    private final UserRoleRepository userRoles;

    public SupabaseJwtAuthenticationConverter(UserRoleRepository userRoles) {
        this.userRoles = userRoles;
    }

    @Override
    public AbstractAuthenticationToken convert(Jwt jwt) {
        UUID userId = UUID.fromString(jwt.getSubject());

        AuthenticatedPrincipal principal = new AuthenticatedPrincipal(
                userId,
                jwt.getClaimAsString(PHONE_CLAIM),
                userRoles.findRoles(userId)
        );

        return UsernamePasswordAuthenticationToken.authenticated(principal, jwt, toAuthorities(principal.roles()));
    }

    private static List<GrantedAuthority> toAuthorities(Set<Role> roles) {
        return roles.stream()
                .map(role -> (GrantedAuthority) new SimpleGrantedAuthority(role.authority()))
                .toList();
    }

}
