package com.proxycare.common.api;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiResponse<T>(
    String message, 
    T data,
    ResponseMeta meta
) {}
