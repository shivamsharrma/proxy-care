package com.proxycare.common.api;

import java.time.Instant;

public record ResponseMeta(
    String traceId,
    Instant timestamp
) {}
