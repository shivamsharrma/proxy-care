package com.proxycare.infrastructure.bank.razorpay.mapper;

import com.proxycare.infrastructure.bank.model.BankBranch;
import com.proxycare.infrastructure.bank.razorpay.dto.response.RazorpayIfscResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper
public interface RazorpayIfscMapper {

    @Mapping(target = "bankName", source = "bank")
    BankBranch toBankBranch(RazorpayIfscResponse razorpayIfscResponse);
}
