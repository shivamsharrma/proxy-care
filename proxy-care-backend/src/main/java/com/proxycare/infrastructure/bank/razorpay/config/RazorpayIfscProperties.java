package com.proxycare.infrastructure.bank.razorpay.config;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;
import org.springframework.validation.annotation.Validated;

/**
 * {@code proxycare.razorpay-ifsc.*}: Razorpay's public IFSC directory (no key).
 *
 * @param baseUrl        e.g. {@code https://ifsc.razorpay.com}
 * @param connectTimeout how long to wait for a connection
 * @param readTimeout    how long to wait for the answer
 */
@Validated
@ConfigurationProperties("proxycare.razorpay-ifsc")
public record RazorpayIfscProperties(
        @DefaultValue("https://ifsc.razorpay.com") @NotBlank String baseUrl,
        @DefaultValue("2s") @NotNull Duration connectTimeout,
        @DefaultValue("5s") @NotNull Duration readTimeout
) {}
