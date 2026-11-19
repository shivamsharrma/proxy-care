package com.proxycare.common.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.http.MediaType;

@ExtendWith(OutputCaptureExtension.class)
class AccessLogTest extends IntegrationTest {

    private static final String PHONE = "+919812345678";
    private static final String OTP = "482913";

    private final UUID userId = UUID.randomUUID();

    @Test
    void oneAccessLineWithMethodPathStatusAndDuration(CapturedOutput output) throws Exception {
        mvc.perform(get("/api/v1/_probe/items").header("Authorization", bearer(userId)))
                .andExpect(status().isOk());

        assertThat(accessLines(output, "GET /api/v1/_probe/items 200")).isEqualTo(1);
    }

    @Test
    void successfulRequestDoesNotLogPhoneOrOtp(CapturedOutput output) throws Exception {
        mvc.perform(post("/api/v1/_probe/validated")
                        .header("Authorization", bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body(30)))
                .andExpect(status().isNoContent());

        assertThat(accessLines(output, "POST /api/v1/_probe/validated 204")).isEqualTo(1);
        assertNoLeak(output);
    }

    @Test
    void validationFailureDoesNotLogPhoneOrOtp(CapturedOutput output) throws Exception {
        mvc.perform(post("/api/v1/_probe/validated")
                        .header("Authorization", bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body(500)))
                .andExpect(status().isBadRequest());

        assertThat(accessLines(output, "POST /api/v1/_probe/validated 400")).isEqualTo(1);
        assertNoLeak(output);
    }

    private static String body(int age) {
        return "{\"phone\":\"" + PHONE + "\",\"otp\":\"" + OTP + "\",\"age\":" + age + "}";
    }

    private static long accessLines(CapturedOutput output, String methodPathStatus) {
        var line = Pattern.compile(Pattern.quote(methodPathStatus) + " \\d+ms");
        return output.getOut().lines().filter(l -> line.matcher(l).find()).count();
    }

    private static void assertNoLeak(CapturedOutput output) {
        assertThat(output.getAll()).doesNotContain("9812345678").doesNotContain(OTP);
    }
}
