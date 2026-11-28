package com.proxycare.infrastructure.bank.gateway;

import com.proxycare.infrastructure.bank.model.BankBranch;
import java.util.Optional;

/** Looks up the bank and branch an IFSC belongs to. */
public interface IIfscDirectory {

    /**
     * The branch for a well-formed IFSC, or empty when the directory doesn't know it. Answers are cached. Throws
     * a SystemException with EXTERNAL_SERVICE_UNAVAILABLE when the directory can't be reached in time, or
     * EXTERNAL_SERVICE_ERROR when it answers with an error.
     */
    Optional<BankBranch> findByIfsc(String ifsc);
}
