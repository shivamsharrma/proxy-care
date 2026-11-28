package com.proxycare.features.caretaker.service;

import com.proxycare.features.caretaker.config.BankVerificationJobProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Sends the Rs 1 test deposit for new payout account attempts and checks pending ones when the webhook hasn't
 * answered, every {@code proxycare.bank-verification.job-delay}. Safe on several instances (rows are claimed with
 * SKIP LOCKED). Tests turn scheduling off and call {@link #processDueAttempts()} directly.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class BankVerificationJob {

    private final BankVerificationAttemptProcessor bankVerificationAttemptProcessor;
    private final BankVerificationJobProperties bankVerificationJobProperties;

    @Scheduled(
            fixedDelayString = "${proxycare.bank-verification.job-delay:PT15S}",
            initialDelayString = "${proxycare.bank-verification.job-delay:PT15S}")
    public void processDueAttempts() {
        try {
            int processedAttempts = 0;
            while (processedAttempts < bankVerificationJobProperties.batchSize()
                    && bankVerificationAttemptProcessor.processNextDueAttempt()) {
                processedAttempts++;
            }
        } catch (RuntimeException runtimeException) {
            // The attempt's transaction rolled back, so it is still due; the next run retries it. Only the type is
            // logged: a database error's text can quote the whole row (holder name, encrypted number).
            log.error("Bank verification run stopped exception={}", runtimeException.getClass().getName());
        }
    }
}
