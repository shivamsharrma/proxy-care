package com.proxycare.infrastructure.payout.model;

/** Where the test deposit is: still running, done (see the account status), or failed. */
public enum ValidationStatus {
    IN_PROGRESS,
    COMPLETED,
    FAILED
}
