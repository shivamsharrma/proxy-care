package com.proxycare.features.caretaker.entity;

import com.proxycare.common.persistence.BaseEntity;
import com.proxycare.features.caretaker.enums.WebhookProvider;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * A webhook delivery already handled, so a redelivery changes nothing. RazorpayX's bank verification is the only
 * webhook so far, so the caretaker feature owns the table until a second feature needs webhooks.
 */
@Entity
@Table(name = "webhook_events")
@Getter
@Setter
@NoArgsConstructor
public class WebhookEventEntity extends BaseEntity {

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, updatable = false)
    private WebhookProvider provider;

    @Column(nullable = false, updatable = false)
    private String eventId;
}
