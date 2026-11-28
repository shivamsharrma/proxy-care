package com.proxycare.features.caretaker.controller;

import com.proxycare.features.caretaker.dto.request.KycDecisionRequest;
import com.proxycare.features.caretaker.dto.response.CaretakerResponse;
import com.proxycare.features.caretaker.service.IAdminCaretakerService;
import jakarta.validation.Valid;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/caretakers")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminCaretakerController {

    private final IAdminCaretakerService adminCaretakerService;

    @PostMapping("/{caretakerId}/kyc-decision")
    public CaretakerResponse decideKyc(
            @PathVariable UUID caretakerId, @Valid @RequestBody KycDecisionRequest kycDecisionRequest) {
        return adminCaretakerService.decideKyc(caretakerId, kycDecisionRequest);
    }
}
