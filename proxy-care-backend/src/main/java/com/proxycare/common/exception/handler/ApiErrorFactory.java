package com.proxycare.common.exception.handler;

import com.proxycare.common.api.ApiError;
import com.proxycare.common.api.ResponseMeta;
import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.logging.MdcKeys;
import java.time.Clock;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;

/** Builds every ApiError, so each one carries the request's trace ID and the time from the Clock. */
@Component
@RequiredArgsConstructor
public class ApiErrorFactory {

    private final Clock clock;

    public ApiError create(ErrorCode errorCode, String message) {
        return create(errorCode, message, null);
    }

    public ApiError create(ErrorCode errorCode, String message, Map<String, String> fieldErrors) {
        return new ApiError(errorCode.name(), message, fieldErrors, currentMeta());
    }

    private ResponseMeta currentMeta() {
        return new ResponseMeta(MDC.get(MdcKeys.TRACE_ID), clock.instant());
    }
}
