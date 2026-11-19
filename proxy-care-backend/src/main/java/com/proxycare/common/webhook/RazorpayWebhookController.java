package com.proxycare.common.webhook;

import com.proxycare.common.config.AppProperties;
import com.proxycare.common.error.AppException;
import com.proxycare.common.error.ErrorCode;
import com.proxycare.common.security.WebhookSignatures;
import java.nio.charset.StandardCharsets;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Receives Razorpay webhooks: verify the signature over the exact raw bytes, then parse, then record
 * once and return 200 quickly. No event types are handled yet; the payments feature adds that.
 */
@RestController
class RazorpayWebhookController {

    // TODO(verify): header names against Razorpay's webhook docs for our account.
    static final String SIGNATURE_HEADER = "X-Razorpay-Signature";
    static final String EVENT_ID_HEADER = "X-Razorpay-Event-Id";

    private final WebhookInbox inbox;
    private final JsonMapper json;
    private final String secret;

    RazorpayWebhookController(WebhookInbox inbox, JsonMapper json, AppProperties props) {
        this.inbox = inbox;
        this.json = json;
        this.secret = props.razorpay().webhookSecret();
    }

    @PostMapping("/webhooks/razorpay")
    ResponseEntity<Void> receive(
            @RequestBody byte[] rawBody,
            @RequestHeader(name = SIGNATURE_HEADER, required = false) String signature,
            @RequestHeader(name = EVENT_ID_HEADER, required = false) String eventId) {
        if (!WebhookSignatures.verify(rawBody, secret, signature)) {
            throw new AppException(ErrorCode.WEBHOOK_SIGNATURE_INVALID, "The webhook signature is invalid.");
        }
        JsonNode event;
        try {
            event = json.readTree(rawBody);
        } catch (JacksonException e) {
            throw new AppException(ErrorCode.MALFORMED_REQUEST, "The webhook body is not valid JSON.");
        }
        if (event == null || !event.isObject()) {
            throw new AppException(ErrorCode.MALFORMED_REQUEST, "The webhook body is not a JSON object.");
        }
        if (eventId == null || eventId.isBlank()) {
            throw new AppException(ErrorCode.VALIDATION_FAILED, EVENT_ID_HEADER + " header is required.");
        }
        String eventType = event.path("event").isString() ? event.path("event").asString() : null;
        inbox.recordIfNew("RAZORPAY", eventId, eventType, new String(rawBody, StandardCharsets.UTF_8));
        return ResponseEntity.ok().build();
    }
}
