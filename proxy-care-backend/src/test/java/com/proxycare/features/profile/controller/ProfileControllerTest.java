package com.proxycare.features.profile.controller;

import static com.proxycare.support.ApiErrorAssert.assertApiError;
import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.features.profile.enums.PreferredLanguage;
import com.proxycare.support.CaretakerRow;
import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

class ProfileControllerTest extends IntegrationTest {

    private static final String PHONE = "+919876543210";
    private static final String ME_PATH = "/api/v1/profile/me";

    private final UUID userId = UUID.randomUUID();

    // ---- GET /api/v1/profile/me ----

    @Test
    void noProfileYetIsProfileNotFound() throws Exception {
        assertApiError(getProfile(), 404, "PROFILE_NOT_FOUND");
    }

    @Test
    void returnsTheCallersProfile() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        getProfile().andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId.toString()))
                .andExpect(jsonPath("$.phone").value(PHONE))
                .andExpect(jsonPath("$.roles", containsInAnyOrder("USER")))
                .andExpect(jsonPath("$.preferredLanguage").value("EN"));
    }

    @Test
    void returnsEveryRole() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER", "CARETAKER");

        getProfile().andExpect(jsonPath("$.roles", containsInAnyOrder("USER", "CARETAKER")));
    }

    @Test
    void neverReturnsSomeoneElsesProfile() throws Exception {
        testDb.insertProfile(UUID.randomUUID(), "+919800000000", "ADMIN");

        assertApiError(getProfile(), 404, "PROFILE_NOT_FOUND");
    }

    @Test
    void getNeedsAToken() throws Exception {
        assertApiError(mockMvc.perform(get(ME_PATH)), 401, "UNAUTHENTICATED");
    }

    // ---- PUT /api/v1/profile/me ----
    // 03_verify_otp.feature: "New account is routed to the first onboarding screen for the app's role",
    // "Existing account goes straight to home", "An account with only the other role starts onboarding
    // for this app's role"; onboarding_navigation_access_control.feature @multi-role scenarios.
    // Plan OQ-5: the language chosen on Welcome (01_welcome.feature) syncs to profiles.preferred_language.

    @Test
    void putCreatesAUserProfileWithThePhoneFromTheToken() throws Exception {
        testDb.insertAuthUser(userId);

        putProfile(profileUpdateBody("USER", "EN"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId.toString()))
                .andExpect(jsonPath("$.phone").value(PHONE))
                .andExpect(jsonPath("$.roles", containsInAnyOrder("USER")))
                .andExpect(jsonPath("$.preferredLanguage").value("EN"));

        assertThat(testDb.rolesOf(userId)).containsExactly("USER");
        assertThat(testDb.phoneOf(userId)).isEqualTo(PHONE);
        assertThat(testDb.preferredLanguageOf(userId)).isEqualTo("EN");
    }

    @Test
    void putCreatesACaretakerProfileWithThePhoneFromTheToken() throws Exception {
        testDb.insertAuthUser(userId);

        putProfile(profileUpdateBody("CARETAKER", "HI"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId.toString()))
                .andExpect(jsonPath("$.phone").value(PHONE))
                .andExpect(jsonPath("$.roles", containsInAnyOrder("CARETAKER")))
                .andExpect(jsonPath("$.preferredLanguage").value("HI"));

        assertThat(testDb.rolesOf(userId)).containsExactly("CARETAKER");
        assertThat(testDb.phoneOf(userId)).isEqualTo(PHONE);
        assertThat(testDb.preferredLanguageOf(userId)).isEqualTo("HI");
    }

    @Test
    void putWithTheSameRoleAgainKeepsTheRolesAndSyncsTheLanguage() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");
        testDb.setPreferredLanguage(userId, PreferredLanguage.HI);

        putProfile(profileUpdateBody("USER", "EN"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId.toString()))
                .andExpect(jsonPath("$.phone").value(PHONE))
                .andExpect(jsonPath("$.roles", containsInAnyOrder("USER")))
                .andExpect(jsonPath("$.preferredLanguage").value("EN"));

        assertThat(testDb.rolesOf(userId)).containsExactly("USER");
        assertThat(testDb.preferredLanguageOf(userId)).isEqualTo("EN");
        assertThat(testDb.count("profiles")).isEqualTo(1);
    }

    @Test
    void putAddsTheUserRoleToACaretaker() throws Exception {
        testDb.insertProfile(userId, PHONE, "CARETAKER");
        testDb.setPreferredLanguage(userId, PreferredLanguage.HI);

        putProfile(profileUpdateBody("USER", "EN"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId.toString()))
                .andExpect(jsonPath("$.phone").value(PHONE))
                .andExpect(jsonPath("$.roles", containsInAnyOrder("CARETAKER", "USER")))
                .andExpect(jsonPath("$.preferredLanguage").value("EN"));

        assertThat(testDb.rolesOf(userId)).containsExactlyInAnyOrder("CARETAKER", "USER");
        assertThat(testDb.phoneOf(userId)).isEqualTo(PHONE);
        assertThat(testDb.preferredLanguageOf(userId)).isEqualTo("EN");
    }

    @Test
    void putAddsTheCaretakerRoleToAUser() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");
        testDb.setPreferredLanguage(userId, PreferredLanguage.HI);

        putProfile(profileUpdateBody("CARETAKER", "EN"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId.toString()))
                .andExpect(jsonPath("$.phone").value(PHONE))
                .andExpect(jsonPath("$.roles", containsInAnyOrder("USER", "CARETAKER")))
                .andExpect(jsonPath("$.preferredLanguage").value("EN"));

        assertThat(testDb.rolesOf(userId)).containsExactlyInAnyOrder("USER", "CARETAKER");
        assertThat(testDb.phoneOf(userId)).isEqualTo(PHONE);
        assertThat(testDb.preferredLanguageOf(userId)).isEqualTo("EN");
    }

    // C1_kyc_checklist.feature "New caretaker sees the MVP checklist after OTP verification": the caretakers row
    // starts at step 2 (mobile verified), so GET /caretakers/me/kyc has progress to show.
    @Test
    void putWithTheCaretakerRoleStartsTheCaretakersOnboarding() throws Exception {
        testDb.insertAuthUser(userId);

        putProfile(profileUpdateBody("CARETAKER", "EN")).andExpect(status().isOk());

        CaretakerRow caretakerRow = testDb.caretakerOf(userId);
        assertThat(caretakerRow).isNotNull();
        assertThat(caretakerRow.status()).isEqualTo("PENDING");
        assertThat(caretakerRow.onboardingStatus()).isEqualTo("IN_PROGRESS");
        assertThat(caretakerRow.videoVerificationStatus()).isEqualTo("PENDING");
        assertThat(caretakerRow.bankVerificationStatus()).isNull();
        assertThat(caretakerRow.kycStep()).isEqualTo(2);
        assertThat(testDb.count("caretakers")).isEqualTo(1);
    }

    // C1_kyc_checklist.feature "Checklist reflects saved progress when resuming": signing in again must not reset it.
    @Test
    void putWithTheCaretakerRoleAgainKeepsTheCaretakersProgress() throws Exception {
        testDb.insertProfile(userId, PHONE, "CARETAKER");
        UUID caretakerRowId = testDb.insertOnboardingCaretaker(userId, 3);

        putProfile(profileUpdateBody("CARETAKER", "EN")).andExpect(status().isOk());
        putProfile(profileUpdateBody("CARETAKER", "HI")).andExpect(status().isOk());

        CaretakerRow caretakerRow = testDb.caretakerOf(userId);
        assertThat(testDb.count("caretakers")).isEqualTo(1);
        assertThat(caretakerRow.id()).isEqualTo(caretakerRowId);
        assertThat(caretakerRow.status()).isEqualTo("PENDING");
        assertThat(caretakerRow.onboardingStatus()).isEqualTo("IN_PROGRESS");
        assertThat(caretakerRow.kycStep()).isEqualTo(3);
    }

    @Test
    void putWithTheAdminRoleDoesNotCreateAProfile() throws Exception {
        testDb.insertAuthUser(userId);

        assertApiError(putProfile(profileUpdateBody("ADMIN", "EN")), 400, "VALIDATION_FAILED");

        assertThat(testDb.count("profiles")).isZero();
    }

    @Test
    void putWithTheAdminRoleLeavesAnExistingProfileUnchanged() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        assertApiError(putProfile(profileUpdateBody("ADMIN", "HI")), 400, "VALIDATION_FAILED");

        assertThat(testDb.rolesOf(userId)).containsExactly("USER");
        assertThat(testDb.preferredLanguageOf(userId)).isEqualTo("EN");
    }

    @Test
    void putNeverTakesTheIdOrPhoneFromTheBody() throws Exception {
        testDb.insertAuthUser(userId);
        UUID someoneElsesId = UUID.randomUUID();
        String someoneElsesPhone = "+919800000000";
        testDb.insertProfile(someoneElsesId, someoneElsesPhone, "CARETAKER");
        String profileUpdateBody = """
                {"role": "USER", "preferredLanguage": "HI", "phone": "%s", "id": "%s"}
                """.formatted(someoneElsesPhone, someoneElsesId);

        putProfile(profileUpdateBody)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId.toString()))
                .andExpect(jsonPath("$.phone").value(PHONE));

        assertThat(testDb.count("profiles")).isEqualTo(2);
        assertThat(testDb.phoneOf(userId)).isEqualTo(PHONE);
        assertThat(testDb.rolesOf(userId)).containsExactly("USER");
        assertThat(testDb.rolesOf(someoneElsesId)).containsExactly("CARETAKER");
        assertThat(testDb.phoneOf(someoneElsesId)).isEqualTo(someoneElsesPhone);
        assertThat(testDb.preferredLanguageOf(someoneElsesId)).isEqualTo("EN");
    }

    @Test
    void putNeverTouchesSomeoneElsesProfile() throws Exception {
        testDb.insertAuthUser(userId);
        UUID someoneElsesId = UUID.randomUUID();
        testDb.insertProfile(someoneElsesId, "+919800000000", "USER");

        putProfile(profileUpdateBody("CARETAKER", "HI")).andExpect(status().isOk());

        assertThat(testDb.rolesOf(someoneElsesId)).containsExactly("USER");
        assertThat(testDb.preferredLanguageOf(someoneElsesId)).isEqualTo("EN");
    }

    @Test
    void putNormalizesATokenPhoneWithoutThePlus() throws Exception {
        testDb.insertAuthUser(userId);
        String tokenWithoutPlus = testTokens.forUser(userId, "919876543210");

        mockMvc.perform(put(ME_PATH)
                        .header("Authorization", "Bearer " + tokenWithoutPlus)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(profileUpdateBody("USER", "EN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.phone").value(PHONE));

        assertThat(testDb.phoneOf(userId)).isEqualTo(PHONE);
    }

    // Jackson rejects a value outside the enum before Bean Validation runs, so it is MALFORMED_REQUEST.
    @ParameterizedTest
    @ValueSource(strings = {
        "{\"role\": \"PILOT\", \"preferredLanguage\": \"EN\"}",
        "{\"role\": \"USER\", \"preferredLanguage\": \"FR\"}",
        "{\"role\": \"USER\", \"preferredLanguage\": \"en\"}",
        "{\"role\": \"user\", \"preferredLanguage\": \"EN\"}"
    })
    void putRejectsAnUnknownRoleOrLanguageAsMalformed(String profileUpdateBody) throws Exception {
        testDb.insertAuthUser(userId);

        assertApiError(putProfile(profileUpdateBody), 400, "MALFORMED_REQUEST");

        assertThat(testDb.count("profiles")).isZero();
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "{\"preferredLanguage\": \"EN\"}",
        "{\"role\": \"USER\"}",
        "{\"role\": null, \"preferredLanguage\": \"EN\"}",
        "{}"
    })
    void putRejectsAMissingRoleOrLanguage(String profileUpdateBody) throws Exception {
        testDb.insertAuthUser(userId);

        assertApiError(putProfile(profileUpdateBody), 400, "VALIDATION_FAILED");

        assertThat(testDb.count("profiles")).isZero();
    }

    @Test
    void putNeedsAToken() throws Exception {
        MockHttpServletRequestBuilder mockHttpServletRequestBuilder = put(ME_PATH)
                .contentType(MediaType.APPLICATION_JSON)
                .content(profileUpdateBody("USER", "EN"));

        assertApiError(mockMvc.perform(mockHttpServletRequestBuilder), 401, "UNAUTHENTICATED");
    }

    private ResultActions getProfile() throws Exception {
        return mockMvc.perform(get(ME_PATH).header("Authorization", callerToken()));
    }

    private ResultActions putProfile(String profileUpdateBody) throws Exception {
        return mockMvc.perform(put(ME_PATH)
                .header("Authorization", callerToken())
                .contentType(MediaType.APPLICATION_JSON)
                .content(profileUpdateBody));
    }

    private String callerToken() {
        return "Bearer " + testTokens.forUser(userId, PHONE);
    }

    private static String profileUpdateBody(String role, String preferredLanguage) {
        return """
                {"role": "%s", "preferredLanguage": "%s"}
                """.formatted(role, preferredLanguage);
    }
}
