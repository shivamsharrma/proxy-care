package com.proxycare.features.caretaker.repository;

import com.proxycare.features.caretaker.entity.WebhookEventEntity;
import com.proxycare.features.caretaker.enums.WebhookProvider;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WebhookEventRepository extends JpaRepository<WebhookEventEntity, UUID> {

    boolean existsByProviderAndEventId(WebhookProvider provider, String eventId);
}
