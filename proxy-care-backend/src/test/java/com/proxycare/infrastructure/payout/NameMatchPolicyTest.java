package com.proxycare.infrastructure.payout;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.infrastructure.payout.model.AccountStatus;
import com.proxycare.infrastructure.payout.model.BankVerification;
import com.proxycare.infrastructure.payout.model.BankVerificationVerdict;
import com.proxycare.infrastructure.payout.model.ValidationStatus;
import org.junit.jupiter.api.Test;

class NameMatchPolicyTest {

    private static final double THRESHOLD = 70.0;
    private static final String HOLDER_NAME = "Anita Sharma";

    private final NameMatchPolicy nameMatchPolicy = new NameMatchPolicy(THRESHOLD);

    @Test
    void scoreAtTheThresholdIsVerified() {
        BankVerificationVerdict bankVerificationVerdict =
                nameMatchPolicy.decide(completedActive("Someone Else", 70.0), HOLDER_NAME);

        assertThat(bankVerificationVerdict).isEqualTo(BankVerificationVerdict.VERIFIED);
    }

    @Test
    void scoreAboveTheThresholdIsVerified() {
        BankVerificationVerdict bankVerificationVerdict =
                nameMatchPolicy.decide(completedActive(HOLDER_NAME, 95.5), HOLDER_NAME);

        assertThat(bankVerificationVerdict).isEqualTo(BankVerificationVerdict.VERIFIED);
    }

    /** The score decides even when the names happen to be equal. */
    @Test
    void scoreBelowTheThresholdIsANameMismatch() {
        BankVerificationVerdict bankVerificationVerdict =
                nameMatchPolicy.decide(completedActive(HOLDER_NAME, 69.9), HOLDER_NAME);

        assertThat(bankVerificationVerdict).isEqualTo(BankVerificationVerdict.NAME_MISMATCH);
    }

    @Test
    void withoutAScoreNamesEqualIgnoringCaseIsVerified() {
        BankVerificationVerdict bankVerificationVerdict =
                nameMatchPolicy.decide(completedActive("ANITA SHARMA", null), "anita sharma");

        assertThat(bankVerificationVerdict).isEqualTo(BankVerificationVerdict.VERIFIED);
    }

    @Test
    void withoutAScoreNamesEqualIgnoringExtraSpacesIsVerified() {
        BankVerificationVerdict bankVerificationVerdict =
                nameMatchPolicy.decide(completedActive("  Anita    Sharma ", null), "Anita Sharma");

        assertThat(bankVerificationVerdict).isEqualTo(BankVerificationVerdict.VERIFIED);
    }

    @Test
    void withoutAScoreNamesEqualIgnoringPunctuationIsVerified() {
        BankVerificationVerdict bankVerificationVerdict =
                nameMatchPolicy.decide(completedActive("Anita K. D'Souza", null), "anita k dsouza");

        assertThat(bankVerificationVerdict).isEqualTo(BankVerificationVerdict.VERIFIED);
    }

    @Test
    void withoutAScoreDifferentNamesAreANameMismatch() {
        BankVerificationVerdict bankVerificationVerdict =
                nameMatchPolicy.decide(completedActive("Anita Verma", null), HOLDER_NAME);

        assertThat(bankVerificationVerdict).isEqualTo(BankVerificationVerdict.NAME_MISMATCH);
    }

    @Test
    void withoutAScoreOrARegisteredNameTheNameCanNotBeVerified() {
        BankVerificationVerdict bankVerificationVerdict =
                nameMatchPolicy.decide(completedActive(null, null), HOLDER_NAME);

        assertThat(bankVerificationVerdict).isEqualTo(BankVerificationVerdict.NAME_VERIFICATION_UNAVAILABLE);
    }

    @Test
    void anInvalidAccountIsADepositFailure() {
        BankVerification bankVerification = new BankVerification(
                "cont_1", "fa_1", "fav_1", ValidationStatus.COMPLETED, AccountStatus.INVALID, HOLDER_NAME, 100.0);

        BankVerificationVerdict bankVerificationVerdict = nameMatchPolicy.decide(bankVerification, HOLDER_NAME);

        assertThat(bankVerificationVerdict).isEqualTo(BankVerificationVerdict.DEPOSIT_FAILED);
    }

    @Test
    void aFailedValidationIsADepositFailure() {
        BankVerification bankVerification = new BankVerification(
                "cont_1", "fa_1", "fav_1", ValidationStatus.FAILED, AccountStatus.UNKNOWN, null, null);

        BankVerificationVerdict bankVerificationVerdict = nameMatchPolicy.decide(bankVerification, HOLDER_NAME);

        assertThat(bankVerificationVerdict).isEqualTo(BankVerificationVerdict.DEPOSIT_FAILED);
    }

    private static BankVerification completedActive(String registeredName, Double nameMatchScore) {
        return new BankVerification(
                "cont_1", "fa_1", "fav_1", ValidationStatus.COMPLETED, AccountStatus.ACTIVE,
                registeredName, nameMatchScore);
    }
}
