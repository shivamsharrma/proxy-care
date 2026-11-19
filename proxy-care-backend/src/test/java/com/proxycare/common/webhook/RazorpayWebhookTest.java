package com.proxycare.common.webhook;

import static com.proxycare.support.ProblemJsonAssert.assertProblem;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;
import java.util.Map;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** No request here sends a JWT: webhooks are authenticated by their signature only. */
class RazorpayWebhookTest extends IntegrationTest {

    private static final String SECRET = "test-webhook-secret"; // application-test.yml
    private static final String BODY = "{\"entity\":\"event\",\"event\":\"payment.captured\",\"payload\":{}}";

    @Autowired
    JdbcTemplate jdbc;

    @Test
    void validSignatureRecordsTheEvent() throws Exception {
        send(BODY, sign(BODY), "evt_1").andExpect(status().isOk());

        assertThat(db.count("webhook_events")).isEqualTo(1);
        Map<String, Object> row = jdbc.queryForMap("select provider, event_id, event_type from webhook_events");
        assertThat(row).containsEntry("provider", "RAZORPAY")
                .containsEntry("event_id", "evt_1")
                .containsEntry("event_type", "payment.captured");
    }

    @Test
    void duplicateEventIdIsAcceptedOnce() throws Exception {
        send(BODY, sign(BODY), "evt_1").andExpect(status().isOk());
        send(BODY, sign(BODY), "evt_1").andExpect(status().isOk());

        assertThat(db.count("webhook_events")).isEqualTo(1);
    }

    @Test
    void invalidSignatureIsRejected() throws Exception {
        assertProblem(send(BODY, sign("{\"other\":true}"), "evt_1"), 401, "WEBHOOK_SIGNATURE_INVALID");

        assertThat(db.count("webhook_events")).isZero();
    }

    @Test
    void missingSignatureIsRejected() throws Exception {
        assertProblem(send(BODY, null, "evt_1"), 401, "WEBHOOK_SIGNATURE_INVALID");

        assertThat(db.count("webhook_events")).isZero();
    }

    @Test
    void missingEventIdIsRejected() throws Exception {
        assertProblem(send(BODY, sign(BODY), null), 400, "VALIDATION_FAILED");

        assertThat(db.count("webhook_events")).isZero();
    }

    @Test
    void malformedJsonWithValidSignatureIsRejected() throws Exception {
        var body = "{not json";

        assertProblem(send(body, sign(body), "evt_1"), 400, "MALFORMED_REQUEST");

        assertThat(db.count("webhook_events")).isZero();
    }

    private ResultActions send(String body, String signature, String eventId) throws Exception {
        MockHttpServletRequestBuilder request = post("/webhooks/razorpay")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body.getBytes(StandardCharsets.UTF_8));
        if (signature != null) {
            request.header("X-Razorpay-Signature", signature);
        }
        if (eventId != null) {
            request.header("X-Razorpay-Event-Id", eventId);
        }
        return mvc.perform(request);
    }

    private static String sign(String body) throws Exception {
        var mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(SECRET.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        return HexFormat.of().formatHex(mac.doFinal(body.getBytes(StandardCharsets.UTF_8)));
    }
}
