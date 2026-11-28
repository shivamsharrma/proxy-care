package com.proxycare.features.caretaker.controller;

import com.proxycare.features.caretaker.dto.request.SaveBasicInformationRequest;
import com.proxycare.features.caretaker.dto.request.SaveIdentityCheckRequest;
import com.proxycare.features.caretaker.dto.request.SavePayoutAccountRequest;
import com.proxycare.features.caretaker.dto.request.VkycBookingRequest;
import com.proxycare.features.caretaker.dto.response.BasicInformationDraftResponse;
import com.proxycare.features.caretaker.dto.response.CaretakerResponse;
import com.proxycare.features.caretaker.dto.response.KycProgressResponse;
import com.proxycare.features.caretaker.dto.response.PayoutAccountResponse;
import com.proxycare.features.caretaker.service.ICaretakerPayoutService;
import com.proxycare.features.caretaker.service.ICaretakerService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/caretakers")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CARETAKER')")
public class CaretakerController {

    private final ICaretakerService caretakerService;
    private final ICaretakerPayoutService caretakerPayoutService;

    @GetMapping("/me")
    public CaretakerResponse me() {
        return caretakerService.getCurrentCaretaker();
    }

    @GetMapping("/me/kyc")
    public KycProgressResponse kycProgress() {
        return caretakerService.getCurrentKycProgress();
    }

    // No @Valid: the service stores the request as the draft before validating it (decision OQ-2).
    @PutMapping("/me/basic-information")
    public KycProgressResponse saveBasicInformation(
            @RequestBody SaveBasicInformationRequest saveBasicInformationRequest) {
        return caretakerService.saveCurrentBasicInformation(saveBasicInformationRequest);
    }

    @GetMapping("/me/basic-information/draft")
    public BasicInformationDraftResponse basicInformationDraft() {
        return caretakerService.getCurrentBasicInformationDraft();
    }

    @PutMapping("/me/identity-check")
    public KycProgressResponse saveIdentityCheck(
            @Valid @RequestBody SaveIdentityCheckRequest saveIdentityCheckRequest) {
        return caretakerService.saveCurrentIdentityCheck(saveIdentityCheckRequest);
    }

    @PutMapping("/me/vkyc-booking")
    public KycProgressResponse rebookVkycCall(@Valid @RequestBody VkycBookingRequest vkycBookingRequest) {
        return caretakerService.rebookCurrentVkycCall(vkycBookingRequest);
    }

    @PutMapping("/me/payout-account")
    public PayoutAccountResponse savePayoutAccount(
            @Valid @RequestBody SavePayoutAccountRequest savePayoutAccountRequest) {
        return caretakerPayoutService.saveCurrentPayoutAccount(savePayoutAccountRequest);
    }

    @GetMapping("/me/payout-account")
    public PayoutAccountResponse payoutAccount() {
        return caretakerPayoutService.getCurrentPayoutAccount();
    }
}
