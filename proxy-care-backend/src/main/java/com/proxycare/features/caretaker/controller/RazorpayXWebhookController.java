package com.proxycare.features.caretaker.controller;

import com.proxycare.features.caretaker.service.IBankVerificationWebhookService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Public (SecurityConfig): RazorpayX calls it without a token, and the signature is the authentication. The body
 * is taken as raw bytes because the signature covers them exactly. Any non-2xx makes RazorpayX retry.
 */
@RestController
@RequestMapping("/api/v1/webhooks/razorpayx")
@RequiredArgsConstructor
public class RazorpayXWebhookController {

    private static final String SIGNATURE_HEADER = "X-Razorpay-Signature";
    private static final String EVENT_ID_HEADER = "X-Razorpay-Event-Id";

    private final IBankVerificationWebhookService bankVerificationWebhookService;

    @PostMapping
    public void receiveWebhook(
            @RequestBody byte[] rawBody,
            @RequestHeader(name = SIGNATURE_HEADER, required = false) String signature,
            @RequestHeader(EVENT_ID_HEADER) String eventId) {
        bankVerificationWebhookService.recordRazorpayXWebhook(rawBody, signature, eventId);
    }
}
