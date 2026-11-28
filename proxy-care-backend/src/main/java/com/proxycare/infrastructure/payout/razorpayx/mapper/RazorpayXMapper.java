package com.proxycare.infrastructure.payout.razorpayx.mapper;

import com.proxycare.infrastructure.payout.model.AccountStatus;
import com.proxycare.infrastructure.payout.model.BankVerification;
import com.proxycare.infrastructure.payout.model.ValidationStatus;
import com.proxycare.infrastructure.payout.razorpayx.dto.response.RazorpayXValidationResponse;
import java.util.Locale;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

@Mapper
public interface RazorpayXMapper {

    String STATUS_COMPLETED = "completed";
    String STATUS_FAILED = "failed";
    String ACCOUNT_STATUS_ACTIVE = "active";
    String ACCOUNT_STATUS_INVALID = "invalid";

    @Mapping(target = "contactId", source = "fundAccount.contactId")
    @Mapping(target = "fundAccountId", source = "fundAccount.id")
    @Mapping(target = "validationId", source = "id")
    @Mapping(target = "validationStatus", source = "status", qualifiedByName = "toValidationStatus")
    @Mapping(target = "accountStatus", source = "results.accountStatus", qualifiedByName = "toAccountStatus")
    @Mapping(target = "registeredName", source = "results.registeredName")
    @Mapping(target = "nameMatchScore", source = "results.nameMatchScore")
    BankVerification toBankVerification(RazorpayXValidationResponse razorpayXValidationResponse);

    // "created" and anything new count as still running.
    @Named("toValidationStatus")
    default ValidationStatus toValidationStatus(String status) {
        String lowerCaseStatus = status == null ? null : status.toLowerCase(Locale.ROOT);
        if (STATUS_COMPLETED.equals(lowerCaseStatus)) {
            return ValidationStatus.COMPLETED;
        }
        return STATUS_FAILED.equals(lowerCaseStatus) ? ValidationStatus.FAILED : ValidationStatus.IN_PROGRESS;
    }

    @Named("toAccountStatus")
    default AccountStatus toAccountStatus(String accountStatus) {
        String lowerCaseAccountStatus = accountStatus == null ? null : accountStatus.toLowerCase(Locale.ROOT);
        if (ACCOUNT_STATUS_ACTIVE.equals(lowerCaseAccountStatus)) {
            return AccountStatus.ACTIVE;
        }
        return ACCOUNT_STATUS_INVALID.equals(lowerCaseAccountStatus) ? AccountStatus.INVALID : AccountStatus.UNKNOWN;
    }
}
