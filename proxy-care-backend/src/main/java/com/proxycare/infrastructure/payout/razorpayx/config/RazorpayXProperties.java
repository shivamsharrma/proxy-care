package com.proxycare.infrastructure.payout.razorpayx.config;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;
import org.springframework.validation.annotation.Validated;

/**
 * {@code proxycare.razorpayx.*}: RazorpayX fund account validation (penny drop). Live mode only: RazorpayX Lite has
 * no test mode for validations.
 *
 * @param baseUrl            e.g. {@code https://api.razorpay.com}
 * @param keyId              Razorpay API key id (the same {@code RAZORPAY_KEY_ID} as payments)
 * @param keySecret          Razorpay API key secret
 * @param accountNumber      our RazorpayX business account the Rs 1 is sent from ({@code RAZORPAYX_ACCOUNT_NUMBER})
 * @param webhookSecret      secret RazorpayX signs webhooks with ({@code RAZORPAYX_WEBHOOK_SECRET})
 * @param nameMatchThreshold lowest {@code name_match_score} that counts as a match
 *                           ({@code RAZORPAYX_NAME_MATCH_THRESHOLD}); required, the score's range is unconfirmed
 * @param connectTimeout     how long to wait for a connection
 * @param readTimeout        how long to wait for an answer
 */
@Validated
@ConfigurationProperties("proxycare.razorpayx")
public record RazorpayXProperties(
        @DefaultValue("https://api.razorpay.com") @NotBlank String baseUrl,
        @NotBlank String keyId,
        @NotBlank String keySecret,
        @NotBlank String accountNumber,
        @NotBlank String webhookSecret,
        @NotNull Double nameMatchThreshold,
        @DefaultValue("2s") @NotNull Duration connectTimeout,
        @DefaultValue("10s") @NotNull Duration readTimeout
) {

    // Secrets and our account number never reach a log line through toString.
    @Override
    public String toString() {
        return "RazorpayXProperties[baseUrl=" + baseUrl + ", nameMatchThreshold=" + nameMatchThreshold + "]";
    }
}
