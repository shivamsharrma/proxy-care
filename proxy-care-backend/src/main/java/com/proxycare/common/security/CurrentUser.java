package com.proxycare.common.security;

import java.util.Set;
import java.util.UUID;

/**
 * The authenticated caller. Controllers take it as {@code @AuthenticationPrincipal CurrentUser me} and
 * always decide whose data to touch from {@code me.id()}, never from a request body or path.
 *
 * @param phone the token's {@code phone} claim; personal data, so log it only through Mask.phone
 * @param roles empty while the user has no profile yet (still onboarding)
 */
public record CurrentUser(UUID id, String phone, Set<Role> roles) {

    /** Mirrors the {@code app_role} Postgres enum. */
    public enum Role {
        USER,
        CARETAKER,
        ADMIN
    }
}
