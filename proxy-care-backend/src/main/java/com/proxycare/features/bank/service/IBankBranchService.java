package com.proxycare.features.bank.service;

import com.proxycare.features.bank.dto.response.BankBranchResponse;

/** Bank branches by IFSC; what other features use to resolve an IFSC on the server instead of trusting the client. */
public interface IBankBranchService {

    /**
     * The branch for a well-formed IFSC. IFSC_NOT_FOUND when no branch has it; EXTERNAL_SERVICE_UNAVAILABLE or
     * EXTERNAL_SERVICE_ERROR when the directory fails.
     */
    BankBranchResponse getBankBranch(String ifsc);
}
