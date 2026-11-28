package com.proxycare.infrastructure.payout.gateway;

import com.proxycare.infrastructure.payout.model.BankVerification;
import com.proxycare.infrastructure.payout.model.BankVerificationCommand;
import java.util.Optional;
import java.util.UUID;

/**
 * Verifies a bank account with a Rs 1 test deposit (penny drop). Every call except {@link #parseWebhook} may throw
 * a SystemException with EXTERNAL_SERVICE_UNAVAILABLE (not reachable in time) or EXTERNAL_SERVICE_ERROR (answered
 * with an error); after either, whether a deposit was sent is unknown until {@link #findVerificationByRequestId}.
 */
public interface IBankVerificationService {

    /**
     * Sends the test deposit for the attempt in the command, tagged with its {@code verificationRequestId}. Sends
     * money: call {@link #findVerificationByRequestId} first whenever an earlier call may have reached the vendor.
     */
    BankVerification requestVerification(BankVerificationCommand bankVerificationCommand);

    /** The deposit already sent for this attempt, if any; how a retry avoids sending a second Rs 1. */
    Optional<BankVerification> findVerificationByRequestId(UUID verificationRequestId);

    /** The current state of a deposit sent earlier. */
    BankVerification fetchVerification(String validationId);

    /**
     * Checks a webhook delivery's signature against its raw body, then reads the deposit it reports; empty when the
     * event is not about a test deposit. WEBHOOK_SIGNATURE_INVALID when the signature is missing or wrong;
     * EXTERNAL_SERVICE_ERROR when a correctly signed body can't be read.
     */
    Optional<BankVerification> parseWebhook(byte[] rawBody, String signature);
}
