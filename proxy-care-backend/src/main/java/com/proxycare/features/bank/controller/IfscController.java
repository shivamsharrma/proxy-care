package com.proxycare.features.bank.controller;

import com.proxycare.common.validation.Ifsc;
import com.proxycare.features.bank.dto.response.BankBranchResponse;
import com.proxycare.features.bank.service.IBankBranchService;
import jakarta.validation.constraints.Pattern;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/ifsc")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CARETAKER')")
public class IfscController {

    private final IBankBranchService bankBranchService;

    @GetMapping("/{ifsc}")
    public BankBranchResponse bankBranch(
            @PathVariable @Pattern(regexp = Ifsc.IFSC_PATTERN, message = Ifsc.IFSC_MESSAGE) String ifsc) {
        return bankBranchService.getBankBranch(ifsc);
    }
}
