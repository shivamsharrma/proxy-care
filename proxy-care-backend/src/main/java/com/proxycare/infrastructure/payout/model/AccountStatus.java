package com.proxycare.infrastructure.payout.model;

/** Whether the bank accepted the test deposit into the account; UNKNOWN until the vendor says. */
public enum AccountStatus {
    ACTIVE,
    INVALID,
    UNKNOWN
}
