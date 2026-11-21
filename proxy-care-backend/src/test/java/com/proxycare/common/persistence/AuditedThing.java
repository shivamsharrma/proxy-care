package com.proxycare.common.persistence;

import jakarta.persistence.Entity;
import jakarta.persistence.Table;

/** Test-only entity for BaseEntityAuditingTest. */
@Entity
@Table(schema = "test_support", name = "audited_things")
class AuditedThing extends BaseEntity {

    private String name;

    protected AuditedThing() {}

    AuditedThing(String name) {
        this.name = name;
    }

    void setName(String name) {
        this.name = name;
    }
}
