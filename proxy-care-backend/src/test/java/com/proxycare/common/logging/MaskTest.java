package com.proxycare.common.logging;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class MaskTest {

    @Test
    void phoneKeepsCountryCodeAndLastFour() {
        assertThat(Mask.phone("+919876543210")).isEqualTo("+91******3210");
    }

    @Test
    void phoneShortOrNull() {
        assertThat(Mask.phone("+9198")).isEqualTo("****");
        assertThat(Mask.phone("")).isEqualTo("****");
        assertThat(Mask.phone(null)).isNull();
    }

    @Test
    void fullyHidesEverything() {
        assertThat(Mask.fully("482913")).isEqualTo("****");
        assertThat(Mask.fully("")).isEqualTo("****");
        assertThat(Mask.fully(null)).isNull();
    }

    @Test
    void last4KeepsOnlyLastFour() {
        assertThat(Mask.last4("123456781234")).isEqualTo("****1234");
        assertThat(Mask.last4("1234")).isEqualTo("****");
        assertThat(Mask.last4("12")).isEqualTo("****");
        assertThat(Mask.last4(null)).isNull();
    }
}
