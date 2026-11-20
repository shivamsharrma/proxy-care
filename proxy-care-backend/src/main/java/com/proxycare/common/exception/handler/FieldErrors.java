package com.proxycare.common.exception.handler;

import java.util.Map;
import java.util.Objects;
import java.util.TreeMap;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/** Turns validation failures into the {@code fieldErrors} map: sorted by field, first message per field wins. */
final class FieldErrors {

    static final String DEFAULT_MESSAGE = "Invalid value";

    private FieldErrors() {}

    static <T> Map<String, String> from(Stream<T> failures, Function<T, String> field, Function<T, String> message) {
        return failures.collect(Collectors.toMap(
                field,
                failure -> Objects.requireNonNullElse(message.apply(failure), DEFAULT_MESSAGE),
                (first, second) -> first,
                TreeMap::new));
    }
}
