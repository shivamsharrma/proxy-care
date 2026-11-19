package com.proxycare.common.idempotency;

import static com.proxycare.support.ProblemJsonAssert.assertProblem;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

class IdempotencyTest extends IntegrationTest {

    private static final String BODY = "{\"name\":\"pay\"}";

    private final UUID userId = UUID.randomUUID();
    private final String key = UUID.randomUUID().toString();

    @Test
    void firstCallRunsTheAction() throws Exception {
        call(userId, key, BODY).andExpect(status().isCreated()).andExpect(header().doesNotExist("Idempotent-Replayed"));

        assertThat(db.count("test_support.idempotent_actions")).isEqualTo(1);
    }

    @Test
    void sameKeyAndBodyIsReplayed() throws Exception {
        var first = call(userId, key, BODY).andReturn().getResponse().getContentAsString();

        var second = call(userId, key, BODY)
                .andExpect(status().isCreated())
                .andExpect(header().string("Idempotent-Replayed", "true"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(second).isEqualTo(first);
        assertThat(db.count("test_support.idempotent_actions")).isEqualTo(1);
    }

    @Test
    void replayIsJsonWithTheSameBody() throws Exception {
        var first = call(userId, key, BODY).andReturn().getResponse().getContentAsString();

        call(userId, key, BODY)
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(content().json(first, org.springframework.test.json.JsonCompareMode.STRICT));
    }

    @Test
    void sameKeyWithDifferentBodyIsRejected() throws Exception {
        call(userId, key, BODY).andExpect(status().isCreated());

        assertProblem(call(userId, key, "{\"name\":\"other\"}"), 422, "IDEMPOTENCY_KEY_REUSED");
        assertThat(db.count("test_support.idempotent_actions")).isEqualTo(1);
    }

    @Test
    void keyMustBeUuid() throws Exception {
        assertProblem(call(userId, "not-a-uuid", BODY), 400, "VALIDATION_FAILED");
        assertThat(db.count("idempotency_keys")).isZero();
    }

    @Test
    void sameKeyForAnotherUserIsIndependent() throws Exception {
        call(userId, key, BODY).andExpect(status().isCreated());

        call(UUID.randomUUID(), key, BODY)
                .andExpect(status().isCreated())
                .andExpect(header().doesNotExist("Idempotent-Replayed"));

        assertThat(db.count("test_support.idempotent_actions")).isEqualTo(2);
    }

    @Test
    void failedActionRollsBackEverythingAndRetrySucceeds() throws Exception {
        assertProblem(call(userId, key, "{\"name\":\"pay\",\"fail\":true}"), 500, "INTERNAL_ERROR");

        assertThat(db.count("idempotency_keys")).isZero();
        assertThat(db.count("test_support.idempotent_actions")).isZero();

        call(userId, key, BODY).andExpect(status().isCreated()).andExpect(header().doesNotExist("Idempotent-Replayed"));
        assertThat(db.count("test_support.idempotent_actions")).isEqualTo(1);
    }

    private ResultActions call(UUID user, String idempotencyKey, String body) throws Exception {
        return mvc.perform(post("/api/v1/_probe/idempotent")
                .header("Authorization", bearer(user))
                .header("Idempotency-Key", idempotencyKey)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body));
    }
}
