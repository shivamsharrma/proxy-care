package com.proxycare.infrastructure.bank.model;

/** A bank branch as the IFSC directory knows it. */
public record BankBranch(String ifsc, String bankName, String branch) {}
