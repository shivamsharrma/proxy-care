package com.proxycare.features.caretaker.service;

/** Penny-drop outcomes pushed by RazorpayX. */
public interface IBankVerificationWebhookService {

    /**
     * Verifies the signature on the raw body, records the event id, then applies the reported outcome to the
     * matching attempt, all in one transaction, so a normal return means the change is stored.
     * WEBHOOK_SIGNATURE_INVALID when the signature is missing or wrong. A repeated event id, an event that isn't
     * about a test deposit, or a validation id no attempt has changes nothing.
     */
    void recordRazorpayXWebhook(byte[] rawBody, String signature, String eventId);
}
