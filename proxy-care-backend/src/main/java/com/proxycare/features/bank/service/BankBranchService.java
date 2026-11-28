package com.proxycare.features.bank.service;

import com.proxycare.features.bank.dto.response.BankBranchResponse;
import com.proxycare.features.bank.exception.IfscNotFoundException;
import com.proxycare.features.bank.mapper.BankBranchMapper;
import com.proxycare.infrastructure.bank.gateway.IIfscDirectory;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class BankBranchService implements IBankBranchService {

    private final IIfscDirectory ifscDirectory;
    private final BankBranchMapper bankBranchMapper;

    @Override
    public BankBranchResponse getBankBranch(String ifsc) {
        return ifscDirectory.findByIfsc(ifsc)
                .map(bankBranchMapper::toBankBranchResponse)
                .orElseThrow(IfscNotFoundException::new);
    }
}
