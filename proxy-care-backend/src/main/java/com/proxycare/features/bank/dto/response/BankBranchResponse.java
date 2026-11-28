package com.proxycare.features.bank.dto.response;

/** The bank and branch an IFSC belongs to, as the server resolved it. */
public record BankBranchResponse(String ifsc, String bankName, String branch) {}
