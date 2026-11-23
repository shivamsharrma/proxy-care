package com.proxycare.features.user.controller;

import static com.proxycare.support.ApiErrorAssert.assertApiError;
import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.AppUserRow;
import com.proxycare.support.IntegrationTest;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** 04_user_profile.feature (Screen 04, User profile Stage A): GET / PUT /api/v1/users/me. */
class AppUserControllerTest extends IntegrationTest {

    private static final String PHONE = "+919876543210";
    private static final String OTHER_PHONE = "+919800000000";
    private static final String ME_PATH = "/api/v1/users/me";

    private static final String RAHUL = "Rahul Sharma";
    private static final String RAHUL_ADDRESS = "Flat 12, Sunrise Apartments, Kothrud, Pune 411038";
    private static final String PRIYA = "Priya Nair";
    private static final String PRIYA_ADDRESS = "22 MG Road, Bengaluru 560001";

    // Devanagari names are written as Unicode escapes: build.gradle.kts does not pin the compile encoding.
    /** "Rahul Sharma" in Devanagari, with vowel signs and a virama. */
    private static final String RAHUL_IN_HINDI = "\u0930\u093E\u0939\u0941\u0932 \u0936\u0930\u094D\u092E\u093E";
    /** "Kamal" in Devanagari, letters only. */
    private static final String KAMAL_IN_HINDI = "\u0915\u092E\u0932";
    /** "Sunita Devi" in Devanagari. */
    private static final String SUNITA_DEVI_IN_HINDI = "\u0938\u0941\u0928\u0940\u0924\u093E \u0926\u0947\u0935\u0940";
    /** "Rahul" in Devanagari followed by the Devanagari digits 1 2 3. */
    private static final String RAHUL_WITH_DEVANAGARI_DIGITS = "\u0930\u093E\u0939\u0941\u0932\u0967\u0968\u0969";
    /** "Rahul" in Devanagari followed by the danda (full stop). */
    private static final String RAHUL_WITH_DANDA = "\u0930\u093E\u0939\u0941\u0932\u0964";
    /** Two aa vowel signs with no letter. */
    private static final String ONLY_VOWEL_SIGNS = "\u093E\u093E";
    /** "Kamal" in Devanagari preceded by an aa vowel sign. */
    private static final String KAMAL_WITH_LEADING_VOWEL_SIGN = "\u093E\u0915\u092E\u0932";
    /** "Rahul" in Latin followed by a Devanagari virama. */
    private static final String RAHUL_WITH_VIRAMA_ON_LATIN = "Rahul\u094D";
    /** The Om sign twice, separated by a space. */
    private static final String OM_TWICE = "\u0950 \u0950";
    /** The avagraha sign twice. */
    private static final String AVAGRAHA_TWICE = "\u093D\u093D";
    /** "Kamal" in Devanagari with a Vedic udatta accent after the first letter. */
    private static final String KAMAL_WITH_VEDIC_ACCENT = "\u0915\u0951\u092E\u0932";
    /** "Zaid" in Devanagari, with a nukta. */
    private static final String ZAID_WITH_NUKTA = "\u091C\u093C\u0948\u0926";
    /** "Sanjay" in Devanagari, with an anusvara. */
    private static final String SANJAY_IN_HINDI = "\u0938\u0902\u091C\u092F";
    /** "Chand" in Devanagari, with a candrabindu. */
    private static final String CHAND_WITH_CANDRABINDU = "\u091A\u093E\u0901\u0926";

    private final UUID userId = UUID.randomUUID();

    // ---- PUT /api/v1/users/me ----

    // Scenario: Completing the profile with a typed address
    @Test
    void savesTheCallersProfile() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        putAppUser(appUserBody(RAHUL, "MALE", 34, RAHUL_ADDRESS))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value(RAHUL))
                .andExpect(jsonPath("$.sex").value("MALE"))
                .andExpect(jsonPath("$.age").value(34))
                .andExpect(jsonPath("$.address").value(RAHUL_ADDRESS))
                .andExpect(jsonPath("$.phone").value(PHONE));

        AppUserRow appUserRow = testDb.appUserOf(userId);
        assertThat(appUserRow).isNotNull();
        assertThat(appUserRow.fullName()).isEqualTo(RAHUL);
        assertThat(appUserRow.sex()).isEqualTo("MALE");
        assertThat(appUserRow.age()).isEqualTo(34);
        assertThat(appUserRow.address()).isEqualTo(RAHUL_ADDRESS);
        assertThat(testDb.count("app_users")).isEqualTo(1);
    }

    // Scenario: Completing the profile without the optional age
    @Test
    void savesWithoutAge() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        putAppUser(appUserBody(PRIYA, "FEMALE", null, PRIYA_ADDRESS))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value(PRIYA))
                .andExpect(jsonPath("$.sex").value("FEMALE"))
                .andExpect(jsonPath("$.age").value(nullValue()))
                .andExpect(jsonPath("$.address").value(PRIYA_ADDRESS))
                .andExpect(jsonPath("$.phone").value(PHONE));

        AppUserRow appUserRow = testDb.appUserOf(userId);
        assertThat(appUserRow).isNotNull();
        assertThat(appUserRow.fullName()).isEqualTo(PRIYA);
        assertThat(appUserRow.sex()).isEqualTo("FEMALE");
        assertThat(appUserRow.age()).isNull();
        assertThat(appUserRow.address()).isEqualTo(PRIYA_ADDRESS);
    }

    @Test
    void savesTheOtherSex() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        putAppUser(appUserBody(RAHUL, "OTHER", 34, RAHUL_ADDRESS))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sex").value("OTHER"));

        assertThat(testDb.appUserOf(userId).sex()).isEqualTo("OTHER");
    }

    // Scenario: Leading and trailing spaces are trimmed from the name
    @Test
    void trimsTheName() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        putAppUser(appUserBody("  Rahul Sharma  ", "MALE", 34, RAHUL_ADDRESS))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value(RAHUL));

        assertThat(testDb.appUserOf(userId).fullName()).isEqualTo(RAHUL);
    }

    // User decision 2026-11-23: Hindi names in Devanagari are accepted and stored as typed.
    @Test
    void savesAHindiName() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        putAppUser(appUserBody(RAHUL_IN_HINDI, "MALE", 34, RAHUL_ADDRESS))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value(RAHUL_IN_HINDI));

        assertThat(testDb.appUserOf(userId).fullName()).isEqualTo(RAHUL_IN_HINDI);
        getAppUser()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value(RAHUL_IN_HINDI));
    }

    @Test
    void savingAgainUpdatesTheSameRow() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");
        UUID appUserId = testDb.insertAppUser(userId, RAHUL, "MALE", 34, RAHUL_ADDRESS);

        putAppUser(appUserBody(PRIYA, "FEMALE", 40, PRIYA_ADDRESS))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value(PRIYA))
                .andExpect(jsonPath("$.sex").value("FEMALE"))
                .andExpect(jsonPath("$.age").value(40))
                .andExpect(jsonPath("$.address").value(PRIYA_ADDRESS))
                .andExpect(jsonPath("$.phone").value(PHONE));

        AppUserRow appUserRow = testDb.appUserOf(userId);
        assertThat(testDb.count("app_users")).isEqualTo(1);
        assertThat(appUserRow.id()).isEqualTo(appUserId);
        assertThat(appUserRow.fullName()).isEqualTo(PRIYA);
        assertThat(appUserRow.sex()).isEqualTo("FEMALE");
        assertThat(appUserRow.age()).isEqualTo(40);
        assertThat(appUserRow.address()).isEqualTo(PRIYA_ADDRESS);
    }

    @Test
    void savingTwiceThroughTheApiKeepsOneRow() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        putAppUser(appUserBody(RAHUL, "MALE", 34, RAHUL_ADDRESS)).andExpect(status().isOk());
        putAppUser(appUserBody(RAHUL, "MALE", 35, RAHUL_ADDRESS)).andExpect(status().isOk());

        assertThat(testDb.count("app_users")).isEqualTo(1);
        assertThat(testDb.appUserOf(userId).age()).isEqualTo(35);
    }

    // PUT replaces the profile: an age left out on a later save is cleared.
    @Test
    void savingAgainWithoutAgeClearsTheAge() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");
        testDb.insertAppUser(userId, RAHUL, "MALE", 34, RAHUL_ADDRESS);

        putAppUser(appUserBody(RAHUL, "MALE", null, RAHUL_ADDRESS))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.age").value(nullValue()));

        assertThat(testDb.appUserOf(userId).age()).isNull();
    }

    @Test
    void userWhoIsAlsoACaretakerCanSaveTheirProfile() throws Exception {
        testDb.insertProfile(userId, PHONE, "CARETAKER", "USER");

        putAppUser(appUserBody(RAHUL, "MALE", 34, RAHUL_ADDRESS)).andExpect(status().isOk());

        assertThat(testDb.appUserOf(userId)).isNotNull();
    }

    // Scenario Outline: Invalid full name values are rejected (R, Rahul123, @@@@, <spaces-only>);
    // Scenario Outline: Missing required fields show inline errors (Full name); ASSUMPTION: 2-50 chars.
    // User decision 2026-11-23: at least one letter; no Latin or Devanagari digits.
    @ParameterizedTest
    @NullSource
    @MethodSource("invalidFullNames")
    void rejectsInvalidFullName(String fullName) throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        assertRejected(appUserBody(fullName, "MALE", 34, RAHUL_ADDRESS), "fullName");
    }

    static Stream<String> invalidFullNames() {
        return Stream.of(
                "R", "Rahul123", "@@@@", "   ", "", "  R  ", "A".repeat(51),
                ".", "..", "--", ". - .", "' '", RAHUL_WITH_DEVANAGARI_DIGITS,
                RAHUL_WITH_DANDA, ONLY_VOWEL_SIGNS, KAMAL_WITH_LEADING_VOWEL_SIGN, RAHUL_WITH_VIRAMA_ON_LATIN,
                OM_TWICE, AVAGRAHA_TWICE, KAMAL_WITH_VEDIC_ACCENT);
    }

    // ASSUMPTION: name 2-50 chars after trimming, letters/spaces/.'- only.
    // User decision 2026-11-23: letters are English A-Z/a-z or Hindi in Devanagari.
    @ParameterizedTest
    @MethodSource("validFullNames")
    void acceptsValidFullNames(String fullName) throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        putAppUser(appUserBody(fullName, "MALE", 34, RAHUL_ADDRESS))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value(fullName.trim()));
    }

    static Stream<String> validFullNames() {
        return Stream.of(
                "Al", "A".repeat(50), "  " + "A".repeat(50) + "  ", "Dr. Anne-Marie O'Neil",
                RAHUL_IN_HINDI, KAMAL_IN_HINDI, SUNITA_DEVI_IN_HINDI,
                ZAID_WITH_NUKTA, SANJAY_IN_HINDI, CHAND_WITH_CANDRABINDU);
    }

    // Scenario Outline: Invalid age values are rejected
    @ParameterizedTest
    @ValueSource(ints = {0, 17, 121})
    void rejectsInvalidAge(int age) throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        assertRejected(appUserBody(RAHUL, "MALE", age, RAHUL_ADDRESS), "age");
    }

    @ParameterizedTest
    @ValueSource(ints = {18, 120})
    void acceptsBoundaryAges(int age) throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        putAppUser(appUserBody(RAHUL, "MALE", age, RAHUL_ADDRESS))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.age").value(age));

        assertThat(testDb.appUserOf(userId).age()).isEqualTo(age);
    }

    @Test
    void rejectsMissingSex() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        assertRejected(appUserBody(RAHUL, null, 34, RAHUL_ADDRESS), "sex");
    }

    // Jackson rejects a value outside the enum before Bean Validation runs, so it is MALFORMED_REQUEST.
    @ParameterizedTest
    @ValueSource(strings = {"UNKNOWN", "male", "M", "F"})
    void rejectsUnknownSex(String sex) throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        assertApiError(putAppUser(appUserBody(RAHUL, sex, 34, RAHUL_ADDRESS)), 400, "MALFORMED_REQUEST");

        assertThat(testDb.count("app_users")).isZero();
    }

    // Scenario Outline: Missing required fields show inline errors (Address)
    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = {"   "})
    void rejectsMissingOrBlankAddress(String address) throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        assertRejected(appUserBody(RAHUL, "MALE", 34, address), "address");
    }

    @Test
    void rejectsAddressLongerThan300Characters() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        assertRejected(appUserBody(RAHUL, "MALE", 34, "a".repeat(301)), "address");
    }

    @Test
    void acceptsAnAddressOfExactly300Characters() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");
        String address = "a".repeat(300);

        putAppUser(appUserBody(RAHUL, "MALE", 34, address)).andExpect(status().isOk());

        assertThat(testDb.appUserOf(userId).address()).isEqualTo(address);
    }

    @Test
    void invalidSaveLeavesTheStoredProfileUnchanged() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");
        testDb.insertAppUser(userId, RAHUL, "MALE", 34, RAHUL_ADDRESS);

        assertApiError(putAppUser(appUserBody("R", "FEMALE", 17, "")), 400, "VALIDATION_FAILED");

        AppUserRow appUserRow = testDb.appUserOf(userId);
        assertThat(appUserRow.fullName()).isEqualTo(RAHUL);
        assertThat(appUserRow.sex()).isEqualTo("MALE");
        assertThat(appUserRow.age()).isEqualTo(34);
        assertThat(appUserRow.address()).isEqualTo(RAHUL_ADDRESS);
    }

    // Screen 04: the mobile is prefilled, verified and read-only, so it comes from the profile, never the body.
    @Test
    void phoneIsNeverTakenFromTheBody() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");
        UUID someoneElsesId = UUID.randomUUID();
        testDb.insertProfile(someoneElsesId, OTHER_PHONE, "USER");
        Map<String, Object> appUserFields = appUserFields(RAHUL, "MALE", 34, RAHUL_ADDRESS);
        appUserFields.put("phone", OTHER_PHONE);
        appUserFields.put("profileId", someoneElsesId.toString());

        putAppUser(objectMapper.writeValueAsString(appUserFields))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.phone").value(PHONE));

        assertThat(testDb.appUserOf(userId)).isNotNull();
        assertThat(testDb.appUserOf(someoneElsesId)).isNull();
        assertThat(testDb.phoneOf(userId)).isEqualTo(PHONE);
        assertThat(testDb.phoneOf(someoneElsesId)).isEqualTo(OTHER_PHONE);
    }

    // Signed in but no profiles row yet (no role chosen), so the caller has no USER role.
    @Test
    void putWithoutAProfileIsAccessDenied() throws Exception {
        assertApiError(putAppUser(appUserBody(RAHUL, "MALE", 34, RAHUL_ADDRESS)), 403, "ACCESS_DENIED");

        assertThat(testDb.count("app_users")).isZero();
    }

    @Test
    void caretakerCannotSaveAUserProfile() throws Exception {
        testDb.insertProfile(userId, PHONE, "CARETAKER");

        assertApiError(putAppUser(appUserBody(RAHUL, "MALE", 34, RAHUL_ADDRESS)), 403, "ACCESS_DENIED");

        assertThat(testDb.count("app_users")).isZero();
    }

    @Test
    void putNeedsAToken() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");
        MockHttpServletRequestBuilder mockHttpServletRequestBuilder = put(ME_PATH)
                .contentType(MediaType.APPLICATION_JSON)
                .content(appUserBody(RAHUL, "MALE", 34, RAHUL_ADDRESS));

        assertApiError(mockMvc.perform(mockHttpServletRequestBuilder), 401, "UNAUTHENTICATED");

        assertThat(testDb.count("app_users")).isZero();
    }

    @Test
    void savingNeverChangesSomeoneElsesProfile() throws Exception {
        UUID someoneElsesId = UUID.randomUUID();
        testDb.insertProfile(someoneElsesId, OTHER_PHONE, "USER");
        UUID someoneElsesAppUserId = testDb.insertAppUser(someoneElsesId, PRIYA, "FEMALE", 40, PRIYA_ADDRESS);
        testDb.insertProfile(userId, PHONE, "USER");

        putAppUser(appUserBody(RAHUL, "MALE", 34, RAHUL_ADDRESS)).andExpect(status().isOk());

        assertThat(testDb.count("app_users")).isEqualTo(2);
        AppUserRow someoneElsesAppUserRow = testDb.appUserOf(someoneElsesId);
        assertThat(someoneElsesAppUserRow.id()).isEqualTo(someoneElsesAppUserId);
        assertThat(someoneElsesAppUserRow.fullName()).isEqualTo(PRIYA);
        assertThat(someoneElsesAppUserRow.sex()).isEqualTo("FEMALE");
        assertThat(someoneElsesAppUserRow.age()).isEqualTo(40);
        assertThat(someoneElsesAppUserRow.address()).isEqualTo(PRIYA_ADDRESS);
        assertThat(testDb.appUserOf(userId).fullName()).isEqualTo(RAHUL);
    }

    // ---- GET /api/v1/users/me ----

    @Test
    void returnsTheSavedProfile() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");
        testDb.insertAppUser(userId, RAHUL, "MALE", 34, RAHUL_ADDRESS);

        getAppUser()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value(RAHUL))
                .andExpect(jsonPath("$.sex").value("MALE"))
                .andExpect(jsonPath("$.age").value(34))
                .andExpect(jsonPath("$.address").value(RAHUL_ADDRESS))
                .andExpect(jsonPath("$.phone").value(PHONE));
    }

    @Test
    void returnsTheSavedProfileWithoutAge() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");
        testDb.insertAppUser(userId, PRIYA, "FEMALE", null, PRIYA_ADDRESS);

        getAppUser()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value(PRIYA))
                .andExpect(jsonPath("$.age").value(nullValue()));
    }

    @Test
    void getWithoutAProfileIsAppUserNotFound() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        assertApiError(getAppUser(), 404, "APP_USER_NOT_FOUND");
    }

    @Test
    void neverReturnsSomeoneElsesProfile() throws Exception {
        UUID someoneElsesId = UUID.randomUUID();
        testDb.insertProfile(someoneElsesId, OTHER_PHONE, "USER");
        testDb.insertAppUser(someoneElsesId, PRIYA, "FEMALE", 40, PRIYA_ADDRESS);
        testDb.insertProfile(userId, PHONE, "USER");

        assertApiError(getAppUser(), 404, "APP_USER_NOT_FOUND");
    }

    @Test
    void getWithoutAProfileIsAccessDenied() throws Exception {
        assertApiError(getAppUser(), 403, "ACCESS_DENIED");
    }

    @Test
    void caretakerCannotReadAUserProfile() throws Exception {
        testDb.insertProfile(userId, PHONE, "CARETAKER");
        testDb.insertAppUser(userId, RAHUL, "MALE", 34, RAHUL_ADDRESS);

        assertApiError(getAppUser(), 403, "ACCESS_DENIED");
    }

    @Test
    void getNeedsAToken() throws Exception {
        assertApiError(mockMvc.perform(get(ME_PATH)), 401, "UNAUTHENTICATED");
    }

    private void assertRejected(String appUserBody, String field) throws Exception {
        assertApiError(putAppUser(appUserBody), 400, "VALIDATION_FAILED")
                .andExpect(jsonPath("$.fieldErrors." + field).exists());

        assertThat(testDb.count("app_users")).isZero();
    }

    private ResultActions getAppUser() throws Exception {
        return mockMvc.perform(get(ME_PATH).header("Authorization", callerToken()));
    }

    private ResultActions putAppUser(String appUserBody) throws Exception {
        return mockMvc.perform(put(ME_PATH)
                .header("Authorization", callerToken())
                .contentType(MediaType.APPLICATION_JSON)
                .content(appUserBody));
    }

    private String callerToken() {
        return "Bearer " + testTokens.forUser(userId, PHONE);
    }

    /** A SaveAppUserRequest body; a null argument leaves that field out. */
    private String appUserBody(String fullName, String sex, Integer age, String address) {
        return objectMapper.writeValueAsString(appUserFields(fullName, sex, age, address));
    }

    private static Map<String, Object> appUserFields(String fullName, String sex, Integer age, String address) {
        Map<String, Object> appUserFields = new LinkedHashMap<>();
        putIfPresent(appUserFields, "fullName", fullName);
        putIfPresent(appUserFields, "sex", sex);
        putIfPresent(appUserFields, "age", age);
        putIfPresent(appUserFields, "address", address);
        return appUserFields;
    }

    private static void putIfPresent(Map<String, Object> appUserFields, String field, Object value) {
        if (value != null) {
            appUserFields.put(field, value);
        }
    }
}
