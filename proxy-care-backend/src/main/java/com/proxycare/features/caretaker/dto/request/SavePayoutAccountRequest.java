package com.proxycare.features.caretaker.dto.request;

import com.proxycare.common.validation.Ifsc;
import com.proxycare.common.validation.PersonName;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * C5 Submit for review. The bank and branch are not taken from the app: the server resolves them from the IFSC.
 * The app checks the confirm-account-number field itself, so only one number arrives.
 */
public record SavePayoutAccountRequest(
        @NotNull
        @Size(min = 2, max = 80)
        @Pattern(regexp = PersonName.FULL_NAME_PATTERN, message = PersonName.FULL_NAME_MESSAGE)
        String accountHolderName,
        @NotNull
        @Pattern(regexp = SavePayoutAccountRequest.ACCOUNT_NUMBER_PATTERN, message = SavePayoutAccountRequest.ACCOUNT_NUMBER_MESSAGE)
        String accountNumber,
        @NotNull @Pattern(regexp = Ifsc.IFSC_PATTERN, message = Ifsc.IFSC_MESSAGE) String ifsc
) {

    static final String ACCOUNT_NUMBER_PATTERN = "[0-9]{9,18}";
    static final String ACCOUNT_NUMBER_MESSAGE = "must be 9 to 18 digits";

    public SavePayoutAccountRequest {
        accountHolderName = accountHolderName == null ? null : accountHolderName.trim();
    }

    // The account number and holder name are personal data, so they never reach a log line through toString.
    @Override
    public String toString() {
        return "SavePayoutAccountRequest[ifsc=" + ifsc + "]";
    }
}
