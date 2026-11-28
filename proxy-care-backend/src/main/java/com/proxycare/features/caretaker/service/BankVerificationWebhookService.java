package com.proxycare.features.caretaker.service;

import com.proxycare.features.caretaker.entity.WebhookEventEntity;
import com.proxycare.features.caretaker.enums.WebhookProvider;
import com.proxycare.features.caretaker.repository.BankVerificationRequestRepository;
import com.proxycare.features.caretaker.repository.WebhookEventRepository;
import com.proxycare.infrastructure.payout.gateway.IBankVerificationService;
import com.proxycare.infrastructure.payout.model.BankVerification;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class BankVerificationWebhookService implements IBankVerificationWebhookService {

    private final IBankVerificationService bankVerificationService;
    private final WebhookEventRepository webhookEventRepository;
    private final BankVerificationRequestRepository bankVerificationRequestRepository;
    private final BankVerificationOutcomeRecorder bankVerificationOutcomeRecorder;

    // A validation id not stored yet (the job hasn't committed) is ignored: the job's own check catches the outcome.
    @Override
    @Transactional
    public void recordRazorpayXWebhook(byte[] rawBody, String signature, String eventId) {
        Optional<BankVerification> reportedBankVerification = bankVerificationService.parseWebhook(rawBody, signature);
        if (webhookEventRepository.existsByProviderAndEventId(WebhookProvider.RAZORPAYX, eventId)) {
            return;
        }
        webhookEventRepository.save(buildWebhookEventEntity(eventId));

        reportedBankVerification.ifPresent(bankVerification -> bankVerificationRequestRepository
                .findByRazorpayxValidationId(bankVerification.validationId())
                .ifPresent(bankVerificationRequestEntity ->
                        bankVerificationOutcomeRecorder.recordOutcome(bankVerificationRequestEntity, bankVerification)));
    }

    private static WebhookEventEntity buildWebhookEventEntity(String eventId) {
        WebhookEventEntity webhookEventEntity = new WebhookEventEntity();
        webhookEventEntity.setProvider(WebhookProvider.RAZORPAYX);
        webhookEventEntity.setEventId(eventId);
        return webhookEventEntity;
    }
}
