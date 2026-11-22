package com.proxycare.common.security.jwt;

import com.proxycare.common.security.authorization.Role;
import com.proxycare.common.security.authorization.IUserRoleProvider;
import com.proxycare.common.security.identity.AuthenticatedUser;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Turns a verified Supabase token into an authentication whose principal is {@link AuthenticatedUser}:
 * identity from the token, roles from {@link IUserRoleProvider}.
 */
@Component
public class SupabaseJwtAuthenticationConverter implements Converter<Jwt, AbstractAuthenticationToken> {

    static final String PHONE_CLAIM = "phone";

    private final IUserRoleProvider userRoleProvider;

    public SupabaseJwtAuthenticationConverter(IUserRoleProvider userRoleProvider) {
        this.userRoleProvider = userRoleProvider;
    }

    @Override
    public AbstractAuthenticationToken convert(Jwt jwt) {
        UUID userId = UUID.fromString(jwt.getSubject());

        AuthenticatedUser authenticatedUser = new AuthenticatedUser(
                userId,
                jwt.getClaimAsString(PHONE_CLAIM),
                userRoleProvider.findRoles(userId)
        );

        return UsernamePasswordAuthenticationToken.authenticated(
                authenticatedUser, jwt, toAuthorities(authenticatedUser.roles()));
    }

    private static List<SimpleGrantedAuthority> toAuthorities(Set<Role> roles) {
        return roles.stream()
                .map(role -> new SimpleGrantedAuthority(role.authority()))
                .toList();
    }

}
