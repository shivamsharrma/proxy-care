package com.proxycare.common.web.filter;

import org.springframework.core.Ordered;

public final class FilterOrder {

    public static final int TRACE_ID = Ordered.HIGHEST_PRECEDENCE;

    public static final int REQUEST_LOGGING = TRACE_ID + 1;

    public static final int API_CACHE_CONTROL = REQUEST_LOGGING + 1;

    public static final int REQUEST_BODY_SIZE_LIMIT = API_CACHE_CONTROL + 1;

    static final int SPRING_SECURITY = -100;

    public static final int USER_ID = SPRING_SECURITY + 1;

    private FilterOrder() {}
}
