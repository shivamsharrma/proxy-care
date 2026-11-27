package com.proxycare.features.caretaker.controller;

import static com.proxycare.support.ApiErrorAssert.assertApiError;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

/**
 * C1_kyc_checklist.feature (Screen C1, KYC checklist): GET /api/v1/caretakers/me/kyc. The client draws the
 * checklist from the steps and routes on the statuses: IN_PROGRESS to the checklist, SUBMITTED to Under review,
 * ACTIVE to Home.
 */
class CaretakerControllerTest extends IntegrationTest {

    private static final String PHONE = "+919988776655";
    private static final String OTHER_PHONE = "+919800000000";
    private static final String KYC_PATH = "/api/v1/caretakers/me/kyc";
    private static final String PROFILE_PATH = "/api/v1/profile/me";

    private final UUID caretakerId = UUID.randomUUID();

    // Scenario: New caretaker sees the MVP checklist after OTP verification
    @Test
    void newCaretakerSeesTheMvpChecklistAfterOtpVerification() throws Exception {
        testDb.insertAuthUser(caretakerId);
        putProfileAsCaretaker().andExpect(status().isOk());

        ResultActions kycProgress = getKycProgress()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andExpect(jsonPath("$.onboardingStatus").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.videoVerificationStatus").value("PENDING"))
                .andExpect(jsonPath("$.bankVerificationStatus").value(nullValue()))
                .andExpect(jsonPath("$.stepNumber").value(2))
                .andExpect(jsonPath("$.totalSteps").value(4))
                .andExpect(jsonPath("$.rejectedReason").value(nullValue()));
        assertStepStates(kycProgress, "DONE", "CURRENT", "TODO", "TODO");
    }

    // Scenario Outline: Checklist reflects saved progress when resuming | basic info saved partially | Step 2 of 4
    // The partial draft itself is stored by B2; here the row is seeded at step 2 only.
    @Test
    void resumingWithBasicInfoSavedPartiallyIsStepTwoOfFour() throws Exception {
        insertCaretakerProfile(caretakerId, PHONE);
        testDb.insertOnboardingCaretaker(caretakerId, 2);

        ResultActions kycProgress = getKycProgress()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.onboardingStatus").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.stepNumber").value(2))
                .andExpect(jsonPath("$.totalSteps").value(4));
        assertStepStates(kycProgress, "DONE", "CURRENT", "TODO", "TODO");
    }

    // Scenario Outline: Checklist reflects saved progress when resuming | basic info completed | Step 3 of 4
    @Test
    void resumingWithBasicInfoCompletedIsStepThreeOfFour() throws Exception {
        insertCaretakerProfile(caretakerId, PHONE);
        testDb.insertOnboardingCaretaker(caretakerId, 3);

        ResultActions kycProgress = getKycProgress()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.onboardingStatus").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.stepNumber").value(3))
                .andExpect(jsonPath("$.totalSteps").value(4));
        assertStepStates(kycProgress, "DONE", "DONE", "CURRENT", "TODO");
    }

    // Scenario Outline: Checklist reflects saved progress when resuming | photo taken and call booked | Step 4 of 4
    @Test
    void resumingWithPhotoTakenAndCallBookedIsStepFourOfFour() throws Exception {
        insertCaretakerProfile(caretakerId, PHONE);
        testDb.insertOnboardingCaretaker(caretakerId, 4);

        ResultActions kycProgress = getKycProgress()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.onboardingStatus").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.stepNumber").value(4))
                .andExpect(jsonPath("$.totalSteps").value(4));
        assertStepStates(kycProgress, "DONE", "DONE", "DONE", "CURRENT");
    }

    // Scenario: Completed steps show as Done
    @Test
    void completedBasicInformationShowsAsDoneAndPhotoAndVideoKycAsCurrent() throws Exception {
        insertCaretakerProfile(caretakerId, PHONE);
        testDb.insertOnboardingCaretaker(caretakerId, 3);

        getKycProgress()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.steps[1].step").value("BASIC_INFORMATION"))
                .andExpect(jsonPath("$.steps[1].state").value("DONE"))
                .andExpect(jsonPath("$.steps[2].step").value("PHOTO_AND_VIDEO_KYC"))
                .andExpect(jsonPath("$.steps[2].state").value("CURRENT"));
    }

    // Scenario: Submitted caretaker is not shown the checklist (the client routes SUBMITTED to Under review)
    // User decision 2026-11-28: once SUBMITTED or COMPLETED, every step is Done and the progress is step 4 of 4.
    @Test
    void submittedCaretakerIsReturnedWithOnboardingSubmitted() throws Exception {
        insertCaretakerProfile(caretakerId, PHONE);
        testDb.insertCaretaker(caretakerId, "PENDING", "SUBMITTED", "PENDING", "PENDING", 4);

        ResultActions kycProgress = getKycProgress()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andExpect(jsonPath("$.onboardingStatus").value("SUBMITTED"))
                .andExpect(jsonPath("$.videoVerificationStatus").value("PENDING"))
                .andExpect(jsonPath("$.bankVerificationStatus").value("PENDING"))
                .andExpect(jsonPath("$.stepNumber").value(4))
                .andExpect(jsonPath("$.totalSteps").value(4));
        assertStepStates(kycProgress, "DONE", "DONE", "DONE", "DONE");
    }

    // User decision 2026-11-28: the all-Done checklist follows onboarding_status, not the stored kyc_step.
    @Test
    void submittedCaretakerSeesEveryStepDoneWhateverTheStoredStep() throws Exception {
        insertCaretakerProfile(caretakerId, PHONE);
        testDb.insertCaretaker(caretakerId, "PENDING", "SUBMITTED", "PENDING", "PENDING", 3);

        ResultActions kycProgress = getKycProgress()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.onboardingStatus").value("SUBMITTED"))
                .andExpect(jsonPath("$.stepNumber").value(4))
                .andExpect(jsonPath("$.totalSteps").value(4));
        assertStepStates(kycProgress, "DONE", "DONE", "DONE", "DONE");
    }

    // Scenario: Active caretaker goes straight to Home (the client routes ACTIVE to Home)
    @Test
    void activeCaretakerIsReturnedAsActiveWithOnboardingCompleted() throws Exception {
        insertCaretakerProfile(caretakerId, PHONE);
        testDb.insertCaretaker(caretakerId, "ACTIVE", "COMPLETED", "APPROVED", "VERIFIED", 4);

        ResultActions kycProgress = getKycProgress()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.onboardingStatus").value("COMPLETED"))
                .andExpect(jsonPath("$.videoVerificationStatus").value("APPROVED"))
                .andExpect(jsonPath("$.bankVerificationStatus").value("VERIFIED"))
                .andExpect(jsonPath("$.stepNumber").value(4))
                .andExpect(jsonPath("$.totalSteps").value(4));
        assertStepStates(kycProgress, "DONE", "DONE", "DONE", "DONE");
    }

    @Test
    void userWhoIsAlsoACaretakerSeesTheirProgress() throws Exception {
        testDb.insertProfile(caretakerId, PHONE, "USER", "CARETAKER");
        testDb.insertOnboardingCaretaker(caretakerId, 3);

        getKycProgress()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stepNumber").value(3));
    }

    // ---- Access control ----

    // Profiles that held the CARETAKER role before B1 have no row until their next PUT /profile/me.
    @Test
    void caretakerWithoutACaretakerRowIsCaretakerNotFound() throws Exception {
        insertCaretakerProfile(caretakerId, PHONE);

        assertApiError(getKycProgress(), 404, "CARETAKER_NOT_FOUND");
    }

    @Test
    void neverReturnsSomeoneElsesProgress() throws Exception {
        UUID someoneElsesId = UUID.randomUUID();
        insertCaretakerProfile(someoneElsesId, OTHER_PHONE);
        testDb.insertCaretaker(someoneElsesId, "ACTIVE", "COMPLETED", "APPROVED", "VERIFIED", 4);
        insertCaretakerProfile(caretakerId, PHONE);

        assertApiError(getKycProgress(), 404, "CARETAKER_NOT_FOUND");
    }

    @Test
    void twoCaretakersEachSeeOnlyTheirOwnProgress() throws Exception {
        UUID otherCaretakerId = UUID.randomUUID();
        insertCaretakerProfile(caretakerId, PHONE);
        testDb.insertOnboardingCaretaker(caretakerId, 2);
        insertCaretakerProfile(otherCaretakerId, OTHER_PHONE);
        testDb.insertCaretaker(otherCaretakerId, "PENDING", "SUBMITTED", "PENDING", "PENDING", 4);

        getKycProgressAs(caretakerId, PHONE)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.onboardingStatus").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.stepNumber").value(2));
        getKycProgressAs(otherCaretakerId, OTHER_PHONE)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.onboardingStatus").value("SUBMITTED"))
                .andExpect(jsonPath("$.stepNumber").value(4));
    }

    @Test
    void neverTakesTheCaretakerFromTheQuery() throws Exception {
        UUID someoneElsesId = UUID.randomUUID();
        insertCaretakerProfile(someoneElsesId, OTHER_PHONE);
        testDb.insertCaretaker(someoneElsesId, "ACTIVE", "COMPLETED", "APPROVED", "VERIFIED", 4);
        insertCaretakerProfile(caretakerId, PHONE);
        testDb.insertOnboardingCaretaker(caretakerId, 2);

        mockMvc.perform(get(KYC_PATH)
                        .param("profileId", someoneElsesId.toString())
                        .param("caretakerId", someoneElsesId.toString())
                        .header("Authorization", callerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andExpect(jsonPath("$.onboardingStatus").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.stepNumber").value(2));
    }

    // A caretakers row is seeded so a 403 here cannot be the 404 of a missing row.
    @Test
    void userOnlyAccountIsAccessDenied() throws Exception {
        testDb.insertProfile(caretakerId, PHONE, "USER");
        testDb.insertOnboardingCaretaker(caretakerId, 2);

        assertApiError(getKycProgress(), 403, "ACCESS_DENIED");
    }

    // Signed in but no profiles row yet (no role chosen), so the caller has no CARETAKER role.
    @Test
    void getWithoutAProfileIsAccessDenied() throws Exception {
        testDb.insertAuthUser(caretakerId);

        assertApiError(getKycProgress(), 403, "ACCESS_DENIED");
    }

    @Test
    void getNeedsAToken() throws Exception {
        assertApiError(mockMvc.perform(get(KYC_PATH)), 401, "UNAUTHENTICATED");
    }

    private void insertCaretakerProfile(UUID profileId, String phone) {
        testDb.insertProfile(profileId, phone, "CARETAKER");
    }

    private static void assertStepStates(
            ResultActions kycProgress,
            String mobileNumberState,
            String basicInformationState,
            String photoAndVideoKycState,
            String payoutAccountState)
            throws Exception {
        kycProgress
                .andExpect(jsonPath("$.steps", hasSize(4)))
                .andExpect(jsonPath("$.steps[0].step").value("MOBILE_NUMBER"))
                .andExpect(jsonPath("$.steps[0].state").value(mobileNumberState))
                .andExpect(jsonPath("$.steps[1].step").value("BASIC_INFORMATION"))
                .andExpect(jsonPath("$.steps[1].state").value(basicInformationState))
                .andExpect(jsonPath("$.steps[2].step").value("PHOTO_AND_VIDEO_KYC"))
                .andExpect(jsonPath("$.steps[2].state").value(photoAndVideoKycState))
                .andExpect(jsonPath("$.steps[3].step").value("PAYOUT_ACCOUNT"))
                .andExpect(jsonPath("$.steps[3].state").value(payoutAccountState));
    }

    private ResultActions putProfileAsCaretaker() throws Exception {
        return mockMvc.perform(put(PROFILE_PATH)
                .header("Authorization", callerToken())
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"role": "CARETAKER", "preferredLanguage": "EN"}
                        """));
    }

    private ResultActions getKycProgress() throws Exception {
        return getKycProgressAs(caretakerId, PHONE);
    }

    private ResultActions getKycProgressAs(UUID profileId, String phone) throws Exception {
        return mockMvc.perform(get(KYC_PATH).header("Authorization", "Bearer " + testTokens.forUser(profileId, phone)));
    }

    private String callerToken() {
        return "Bearer " + testTokens.forUser(caretakerId, PHONE);
    }
}
