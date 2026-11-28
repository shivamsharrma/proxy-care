package com.proxycare.features.bank.mapper;

import com.proxycare.features.bank.dto.response.BankBranchResponse;
import com.proxycare.infrastructure.bank.model.BankBranch;
import org.mapstruct.Mapper;

@Mapper
public interface BankBranchMapper {

    BankBranchResponse toBankBranchResponse(BankBranch bankBranch);
}
