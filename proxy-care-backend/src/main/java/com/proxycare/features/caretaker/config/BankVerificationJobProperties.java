package com.proxycare.features.caretaker.config;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;
import org.springframework.validation.annotation.Validated;

/**
 * {@code proxycare.bank-verification.*}: how BankVerificationJob paces penny-drop attempts.
 *
 * @param jobDelay        pause between job runs (ISO-8601, e.g. {@code PT15S}, since {@code @Scheduled} reads it)
 * @param firstCheckDelay after sending the Rs 1, when the job first checks the outcome itself
 * @param pollInterval    between later checks, and before retrying after a vendor failure; the webhook usually
 *                        answers first
 * @param batchSize       most attempts handled per run
 */
@Validated
@ConfigurationProperties("proxycare.bank-verification")
public record BankVerificationJobProperties(
        @DefaultValue("PT15S") @NotNull Duration jobDelay,
        @DefaultValue("30s") @NotNull Duration firstCheckDelay,
        @DefaultValue("10m") @NotNull Duration pollInterval,
        @DefaultValue("20") @Positive int batchSize
) {}
