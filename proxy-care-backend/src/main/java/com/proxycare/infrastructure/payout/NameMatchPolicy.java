package com.proxycare.infrastructure.payout;

import com.proxycare.infrastructure.payout.model.AccountStatus;
import com.proxycare.infrastructure.payout.model.BankVerification;
import com.proxycare.infrastructure.payout.model.BankVerificationVerdict;
import com.proxycare.infrastructure.payout.model.ValidationStatus;
import java.util.Locale;

/**
 * Decides a test deposit's outcome (user decision 2026-11-28):
 * <ul>
 *   <li>failed, or completed into an account that isn't active: DEPOSIT_FAILED;</li>
 *   <li>completed and active with a name match score: VERIFIED when the score reaches the threshold, else
 *       NAME_MISMATCH;</li>
 *   <li>no score: the entered holder name and the bank's registered name compared after normalizing (upper case,
 *       punctuation removed, whitespace collapsed and trimmed): VERIFIED when equal, else NAME_MISMATCH;</li>
 *   <li>neither a score nor a registered name: NAME_VERIFICATION_UNAVAILABLE.</li>
 * </ul>
 * A missing score alone is never a match or a mismatch. Still running: PENDING.
 */
public class NameMatchPolicy {

    private static final String PUNCTUATION = "\\p{P}";
    private static final String WHITESPACE_RUN = "[\\s\\p{Z}]+";
    private static final String SPACE = " ";
    private static final String NOTHING = "";

    private final double nameMatchThreshold;

    public NameMatchPolicy(double nameMatchThreshold) {
        this.nameMatchThreshold = nameMatchThreshold;
    }

    public BankVerificationVerdict decide(BankVerification bankVerification, String accountHolderName) {
        if (bankVerification.validationStatus() == ValidationStatus.FAILED) {
            return BankVerificationVerdict.DEPOSIT_FAILED;
        }
        if (bankVerification.validationStatus() != ValidationStatus.COMPLETED) {
            return BankVerificationVerdict.PENDING;
        }
        if (bankVerification.accountStatus() != AccountStatus.ACTIVE) {
            return BankVerificationVerdict.DEPOSIT_FAILED;
        }
        if (bankVerification.nameMatchScore() != null) {
            return bankVerification.nameMatchScore() >= nameMatchThreshold
                    ? BankVerificationVerdict.VERIFIED
                    : BankVerificationVerdict.NAME_MISMATCH;
        }
        if (bankVerification.registeredName() == null || bankVerification.registeredName().isBlank()) {
            return BankVerificationVerdict.NAME_VERIFICATION_UNAVAILABLE;
        }
        return toComparableName(accountHolderName).equals(toComparableName(bankVerification.registeredName()))
                ? BankVerificationVerdict.VERIFIED
                : BankVerificationVerdict.NAME_MISMATCH;
    }

    private static String toComparableName(String name) {
        return name.toUpperCase(Locale.ROOT)
                .replaceAll(PUNCTUATION, NOTHING)
                .replaceAll(WHITESPACE_RUN, SPACE)
                .trim();
    }
}
