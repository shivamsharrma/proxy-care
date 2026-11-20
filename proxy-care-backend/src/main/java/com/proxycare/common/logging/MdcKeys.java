package com.proxycare.common.logging;

/** Names of the values the app puts in the logging MDC, so every reader and writer uses the same key. */
public final class MdcKeys {

    public static final String TRACE_ID = "traceId";

    /** Set and removed by {@code UserIdMdcFilter} for authenticated requests. */
    public static final String USER_ID = "userId";

    private MdcKeys() {}
}
