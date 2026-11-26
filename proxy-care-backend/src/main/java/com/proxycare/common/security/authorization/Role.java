package com.proxycare.common.security.authorization;

/**
 * Application roles. Stored by name in {@code profiles.roles} (text[]), so never rename one.
 */
public enum Role {

    USER,
    CARETAKER,
    ADMIN;

    private static final String AUTHORITY_PREFIX = "ROLE_";

    /** Spring Security authority, matched by {@code hasRole("CARETAKER")}. */
    public String authority() {
        return AUTHORITY_PREFIX + name();
    }

}
