package com.proxycare.features.caretaker.controller;

import com.proxycare.features.caretaker.dto.response.KycProgressResponse;
import com.proxycare.features.caretaker.service.ICaretakerService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/caretakers")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CARETAKER')")
public class CaretakerKycController {

    private final ICaretakerService caretakerService;

    @GetMapping("/me/kyc")
    public KycProgressResponse kycProgress() {
        return caretakerService.getCurrentKycProgress();
    }
}
