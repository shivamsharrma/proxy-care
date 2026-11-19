package com.proxycare.common.idempotency;

import static com.proxycare.support.ProblemJsonAssert.assertProblem;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import com.proxycare.support.ProbeGate;
import java.util.ArrayList;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.web.servlet.ResultActions;

/** The test profile sets proxycare.idempotency.lock-timeout=500ms. */
class IdempotencyConcurrencyTest extends IntegrationTest {

    private final UUID userId = UUID.randomUUID();
    private final String key = UUID.randomUUID().toString();

    @AfterEach
    void releaseGate() {
        ProbeGate.reset();
    }

    @Test
    void parallelDuplicatesRunTheActionExactlyOnce() throws Exception {
        var start = new CountDownLatch(1);
        try (var pool = Executors.newFixedThreadPool(10)) {
            var futures = new ArrayList<Future<MockHttpServletResponse>>();
            for (int i = 0; i < 10; i++) {
                futures.add(pool.submit(() -> {
                    start.await();
                    return call("{\"name\":\"pay\"}").andReturn().getResponse();
                }));
            }
            start.countDown();

            var bodies = new ArrayList<String>();
            for (var future : futures) {
                var response = future.get(30, TimeUnit.SECONDS);
                assertThat(response.getStatus()).isEqualTo(201);
                bodies.add(response.getContentAsString());
            }
            assertThat(bodies).allMatch(b -> b.equals(bodies.getFirst()));
        }
        assertThat(db.count("test_support.idempotent_actions")).isEqualTo(1);
    }

    @Test
    void duplicateWaitingLongerThanLockTimeoutGets409ThenReplay() throws Exception {
        ProbeGate.close();
        var body = "{\"name\":\"pay\",\"block\":true}";
        try (var pool = Executors.newSingleThreadExecutor()) {
            var first = pool.submit(() -> call(body).andReturn().getResponse());
            ProbeGate.awaitEntered();

            assertProblem(call(body), 409, "IDEMPOTENCY_IN_PROGRESS");

            ProbeGate.open();
            assertThat(first.get(30, TimeUnit.SECONDS).getStatus()).isEqualTo(201);
        }

        call(body).andExpect(status().isCreated()).andExpect(header().string("Idempotent-Replayed", "true"));
        assertThat(db.count("test_support.idempotent_actions")).isEqualTo(1);
    }

    private ResultActions call(String body) throws Exception {
        return mvc.perform(post("/api/v1/_probe/idempotent")
                .header("Authorization", bearer(userId))
                .header("Idempotency-Key", key)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body));
    }
}
