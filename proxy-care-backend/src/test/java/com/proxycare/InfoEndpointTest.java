package com.proxycare;

import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.blankOrNullString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import org.junit.jupiter.api.Test;

class InfoEndpointTest extends IntegrationTest {

    @Test
    void showsBuildVersionAndGitCommit() throws Exception {
        mvc.perform(get("/actuator/info"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.build.version", not(blankOrNullString())))
                .andExpect(jsonPath("$.git.commit.id", not(blankOrNullString())));
    }
}
