package com.proxycare.common.persistence;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

interface AuditedThingRepository extends JpaRepository<AuditedThing, UUID> {}
