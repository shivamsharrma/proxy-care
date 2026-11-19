package com.proxycare.common.web;

import java.util.List;
import org.springframework.data.domain.Slice;

/** The shape of every list response. Page size limits come from spring.data.web.pageable. */
public record PageResponse<T>(List<T> items, int page, int size, boolean hasNext) {

    public static <T> PageResponse<T> from(Slice<T> slice) {
        return new PageResponse<>(slice.getContent(), slice.getNumber(), slice.getSize(), slice.hasNext());
    }
}
