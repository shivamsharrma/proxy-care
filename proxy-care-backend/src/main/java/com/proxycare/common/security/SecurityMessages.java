package com.proxycare.common.security;

/** The client-facing text of security errors, so every 401 and every 403 says the same thing. */
public final class SecurityMessages {

    public static final String UNAUTHENTICATED = "Authentication is required";
    public static final String ACCESS_DENIED = "You are not allowed to do this";

    private SecurityMessages() {}

}
