package com.proxycare.features.patient.controller;

import static com.proxycare.support.ApiErrorAssert.assertApiError;
import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import com.proxycare.support.MutableClock;
import com.proxycare.support.PatientRow;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import tools.jackson.databind.JsonNode;

/**
 * 05_add_family_member.feature (Screen 05) and the list in 06_family_linked.feature (Screen 06):
 * POST / GET /api/v1/patients.
 */
class PatientControllerTest extends IntegrationTest {

    private static final String PHONE = "+919876543210";
    private static final String OTHER_PHONE = "+919800000000";
    private static final String PATIENTS_PATH = "/api/v1/patients";

    // Background: "my profile address is Flat 12, Sunrise Apartments, Kothrud, Pune 411038".
    private static final String RAHUL = "Rahul Sharma";
    private static final String RAHUL_ADDRESS = "Flat 12, Sunrise Apartments, Kothrud, Pune 411038";
    private static final String RAHUL_NEW_ADDRESS = "B-4, Green Park Society, Baner, Pune 411045";
    private static final String PRIYA = "Priya Nair";
    private static final String PRIYA_ADDRESS = "22 MG Road, Bengaluru 560001";

    private static final String SURESH = "Suresh Sharma";
    private static final String SURESH_HEALTH_NOTES = "Diabetic, needs help on stairs";
    private static final String LATA_IYER = "Lata Iyer";
    private static final String LATA_IYER_ADDRESS = "5 Lake View Road, Chennai 600028";
    private static final String LATA_IYER_MOBILE = "9123456780";
    private static final String LATA_SHARMA = "Lata Sharma";
    private static final String INDIA_COUNTRY_CODE = "+91";

    // Devanagari names are written as Unicode escapes: build.gradle.kts does not pin the compile encoding.
    /** "Rahul Sharma" in Devanagari, with vowel signs and a virama. */
    private static final String RAHUL_IN_HINDI = "\u0930\u093E\u0939\u0941\u0932 \u0936\u0930\u094D\u092E\u093E";
    /** "Zaid" in Devanagari, with a nukta. */
    private static final String ZAID_WITH_NUKTA = "\u091C\u093C\u0948\u0926";
    /** "Chand" in Devanagari, with a candrabindu. */
    private static final String CHAND_WITH_CANDRABINDU = "\u091A\u093E\u0901\u0926";
    /** "Rahul" in Devanagari followed by the Devanagari digits 1 2 3. */
    private static final String RAHUL_WITH_DEVANAGARI_DIGITS = "\u0930\u093E\u0939\u0941\u0932\u0967\u0968\u0969";
    /** Two aa vowel signs with no letter. */
    private static final String ONLY_VOWEL_SIGNS = "\u093E\u093E";
    /** The Om sign twice, separated by a space. */
    private static final String OM_TWICE = "\u0950 \u0950";

    private final UUID userId = UUID.randomUUID();

    // ---- POST /api/v1/patients ----

    // Scenario: Adding a parent who lives with the user
    @Test
    void createsAPatientAtTheUsersAddress() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();

        String patientResponseBody = postPatient(patientBody(sureshFields()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.relation").value("FATHER"))
                .andExpect(jsonPath("$.fullName").value(SURESH))
                .andExpect(jsonPath("$.age").value(68))
                .andExpect(jsonPath("$.sex").value("MALE"))
                .andExpect(jsonPath("$.mobile").value(nullValue()))
                .andExpect(jsonPath("$.livesAtUserAddress").value(true))
                .andExpect(jsonPath("$.address").value(RAHUL_ADDRESS))
                .andExpect(jsonPath("$.mobility").value("WHEELCHAIR"))
                .andExpect(jsonPath("$.healthNotes").value(SURESH_HEALTH_NOTES))
                .andReturn()
                .getResponse()
                .getContentAsString();

        PatientRow patientRow = onlyPatientOf(appUserId);
        assertThat(patientRow.id()).hasToString(idOf(patientResponseBody));
        assertThat(patientRow.relation()).isEqualTo("FATHER");
        assertThat(patientRow.fullName()).isEqualTo(SURESH);
        assertThat(patientRow.age()).isEqualTo(68);
        assertThat(patientRow.sex()).isEqualTo("MALE");
        assertThat(patientRow.mobileCountryCode()).isNull();
        assertThat(patientRow.mobileNumber()).isNull();
        assertThat(patientRow.livesAtUserAddress()).isTrue();
        assertThat(patientRow.address()).isEqualTo(RAHUL_ADDRESS);
        assertThat(patientRow.mobility()).isEqualTo("WHEELCHAIR");
        assertThat(patientRow.healthNotes()).isEqualTo(SURESH_HEALTH_NOTES);
    }

    // Scenario: Adding a family member who lives at a different address with own mobile
    @Test
    void createsAPatientAtItsOwnAddressWithMobile() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();

        postPatient(patientBody(lataIyerFields()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.relation").value("MOTHER"))
                .andExpect(jsonPath("$.fullName").value(LATA_IYER))
                .andExpect(jsonPath("$.age").value(72))
                .andExpect(jsonPath("$.sex").value("FEMALE"))
                .andExpect(jsonPath("$.mobile.countryCode").value(INDIA_COUNTRY_CODE))
                .andExpect(jsonPath("$.mobile.number").value(LATA_IYER_MOBILE))
                .andExpect(jsonPath("$.livesAtUserAddress").value(false))
                .andExpect(jsonPath("$.address").value(LATA_IYER_ADDRESS))
                .andExpect(jsonPath("$.mobility").value("AMBULATORY"))
                .andExpect(jsonPath("$.healthNotes").value(nullValue()));

        PatientRow patientRow = onlyPatientOf(appUserId);
        assertThat(patientRow.fullName()).isEqualTo(LATA_IYER);
        assertThat(patientRow.mobileCountryCode()).isEqualTo(INDIA_COUNTRY_CODE);
        assertThat(patientRow.mobileNumber()).isEqualTo(LATA_IYER_MOBILE);
        assertThat(patientRow.livesAtUserAddress()).isFalse();
        assertThat(patientRow.address()).isEqualTo(LATA_IYER_ADDRESS);
        assertThat(patientRow.healthNotes()).isNull();
    }

    // Scenario Outline: Each mobility category is saved with the right enum
    @ParameterizedTest
    @ValueSource(strings = {"AMBULATORY", "WHEELCHAIR", "BEDRIDDEN"})
    void savesEachMobility(String mobility) throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("mobility", mobility);

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.mobility").value(mobility));

        assertThat(onlyPatientOf(appUserId).mobility()).isEqualTo(mobility);
    }

    // Scenario Outline: Each relation is saved with the right enum
    @ParameterizedTest
    @ValueSource(strings = {"FATHER", "MOTHER", "SPOUSE", "GRANDPARENT", "SIBLING", "OTHER"})
    void savesEachRelation(String relation) throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("relation", relation);

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.relation").value(relation));

        assertThat(onlyPatientOf(appUserId).relation()).isEqualTo(relation);
    }

    @ParameterizedTest
    @ValueSource(strings = {"FEMALE", "MALE", "OTHER"})
    void savesEachSex(String sex) throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("sex", sex);

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.sex").value(sex));

        assertThat(onlyPatientOf(appUserId).sex()).isEqualTo(sex);
    }

    // Scenario Outline: Missing required fields block saving (Relation, Full name, Age, Sex, Mobility)
    @ParameterizedTest
    @ValueSource(strings = {"relation", "fullName", "age", "sex", "mobility", "livesAtUserAddress"})
    void rejectsAMissingRequiredField(String field) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.remove(field);

        assertRejected(patientBody(patientFields), field);
    }

    // User decision 2026-11-24: same name rule as the user name (B2), length 2-80, trimmed.
    @Test
    void trimsTheFullName() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("fullName", "  " + SURESH + "  ");

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.fullName").value(SURESH));

        assertThat(onlyPatientOf(appUserId).fullName()).isEqualTo(SURESH);
    }

    @ParameterizedTest
    @MethodSource("validFullNames")
    void acceptsValidFullNames(String fullName) throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("fullName", fullName);

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.fullName").value(fullName.trim()));

        assertThat(onlyPatientOf(appUserId).fullName()).isEqualTo(fullName.trim());
    }

    static Stream<String> validFullNames() {
        return Stream.of(
                "Al", "A".repeat(80), "  " + "A".repeat(80) + "  ", "Dr. Anne-Marie O'Neil",
                RAHUL_IN_HINDI, ZAID_WITH_NUKTA, CHAND_WITH_CANDRABINDU);
    }

    @ParameterizedTest
    @NullSource
    @MethodSource("invalidFullNames")
    void rejectsInvalidFullName(String fullName) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("fullName", fullName);

        assertRejected(patientBody(patientFields), "fullName");
    }

    static Stream<String> invalidFullNames() {
        return Stream.of(
                "S", "Suresh123", "@@@@", "   ", "", "  S  ", "A".repeat(81), "..", "--",
                RAHUL_WITH_DEVANAGARI_DIGITS, ONLY_VOWEL_SIGNS, OM_TWICE);
    }

    // ASSUMPTION in spec 05: patient age whole number 0-120.
    @ParameterizedTest
    @ValueSource(ints = {0, 120})
    void acceptsBoundaryAges(int age) throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("age", age);

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.age").value(age));

        assertThat(onlyPatientOf(appUserId).age()).isEqualTo(age);
    }

    // Scenario Outline: Invalid age for the family member (121, 999); plus the lower boundary and a missing age.
    @ParameterizedTest
    @NullSource
    @ValueSource(ints = {-1, 121, 999})
    void rejectsInvalidAge(Integer age) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("age", age);

        assertRejected(patientBody(patientFields), "age");
    }

    // Review B3a rounds 1-2: age is a whole number; a JSON fraction (even 68.0) is never coerced, and
    // Jackson rejects it before Bean Validation runs, so it is MALFORMED_REQUEST.
    @ParameterizedTest
    @ValueSource(doubles = {68.5, 68.0})
    void rejectsAFractionalAge(double age) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("age", age);

        assertApiError(postPatient(patientBody(patientFields)), 400, "MALFORMED_REQUEST");

        assertThat(testDb.count("patients")).isZero();
    }

    // Scenario Outline: Optional mobile must be valid when entered (12345, 0123456789, 5123456789).
    // User decision 2026-11-24: mobile is {countryCode, number}; MVP countryCode is +91 only.
    @ParameterizedTest
    @MethodSource("invalidMobiles")
    void rejectsInvalidMobile(String countryCode, String number, String field) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("mobile", mobileFields(countryCode, number));

        assertRejected(patientBody(patientFields), field);
    }

    static Stream<Arguments> invalidMobiles() {
        return Stream.of(
                Arguments.of(INDIA_COUNTRY_CODE, "12345", "mobile.number"),
                Arguments.of(INDIA_COUNTRY_CODE, "0123456789", "mobile.number"),
                Arguments.of(INDIA_COUNTRY_CODE, "5123456789", "mobile.number"),
                Arguments.of(INDIA_COUNTRY_CODE, "91234567801", "mobile.number"),
                Arguments.of(INDIA_COUNTRY_CODE, "912345678a", "mobile.number"),
                Arguments.of(INDIA_COUNTRY_CODE, "", "mobile.number"),
                Arguments.of(INDIA_COUNTRY_CODE, null, "mobile.number"),
                Arguments.of("+1", LATA_IYER_MOBILE, "mobile.countryCode"),
                Arguments.of("91", LATA_IYER_MOBILE, "mobile.countryCode"),
                Arguments.of(null, LATA_IYER_MOBILE, "mobile.countryCode"));
    }

    // Scenario: Leaving the optional mobile empty is allowed
    @Test
    void savesWithoutMobile() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.remove("mobile");

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.mobile").value(nullValue()));

        PatientRow patientRow = onlyPatientOf(appUserId);
        assertThat(patientRow.mobileCountryCode()).isNull();
        assertThat(patientRow.mobileNumber()).isNull();
    }

    @Test
    void savesWithAnExplicitlyNullMobile() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("mobile", null);

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.mobile").value(nullValue()));

        PatientRow patientRow = onlyPatientOf(appUserId);
        assertThat(patientRow.mobileCountryCode()).isNull();
        assertThat(patientRow.mobileNumber()).isNull();
    }

    // Scenario: Address is required when "Lives at my address" is off
    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = {"   "})
    void addressRequiredWhenNotLivingAtUserAddress(String address) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("address", address);

        assertRejected(patientBody(patientFields), "address");
    }

    // Same limit as the user address (B2).
    @Test
    void rejectsAnOwnAddressLongerThan300Characters() throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("address", "a".repeat(301));

        assertRejected(patientBody(patientFields), "address");
    }

    @Test
    void acceptsAnOwnAddressOfExactly300Characters() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        String address = "a".repeat(300);
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("address", address);

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.address").value(address));

        assertThat(onlyPatientOf(appUserId).address()).isEqualTo(address);
    }

    // User decision 2026-11-24 (B3a review round 1): the own address is trimmed.
    @Test
    void trimsTheOwnAddress() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("address", "  " + LATA_IYER_ADDRESS + "  ");

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.address").value(LATA_IYER_ADDRESS));

        assertThat(onlyPatientOf(appUserId).address()).isEqualTo(LATA_IYER_ADDRESS);
    }

    // The 300 limit counts the trimmed address.
    @Test
    void acceptsAnOwnAddressOf300CharactersWithSurroundingSpaces() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        String address = "a".repeat(300);
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("address", "   " + address + "   ");

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.address").value(address));

        assertThat(onlyPatientOf(appUserId).address()).isEqualTo(address);
    }

    // Scenario: Turning the address toggle back on discards the separate address
    @Test
    void ignoresTheBodyAddressWhenLivingAtUserAddress() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("livesAtUserAddress", true);

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.livesAtUserAddress").value(true))
                .andExpect(jsonPath("$.address").value(RAHUL_ADDRESS));

        PatientRow patientRow = onlyPatientOf(appUserId);
        assertThat(patientRow.livesAtUserAddress()).isTrue();
        assertThat(patientRow.address()).isEqualTo(RAHUL_ADDRESS);
    }

    // Review B3a round 1, MINOR 10: the address is the user's address at save time, not a stale copy.
    @Test
    void copiesTheUsersCurrentAddress() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        testDb.setAppUserAddressForProfile(userId, RAHUL_NEW_ADDRESS);

        postPatient(patientBody(sureshFields()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.address").value(RAHUL_NEW_ADDRESS));

        assertThat(onlyPatientOf(appUserId).address()).isEqualTo(RAHUL_NEW_ADDRESS);
    }

    // Scenario: Health notes character limit (ASSUMPTION: max 500 chars)
    @Test
    void acceptsHealthNotesOfExactly500Characters() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        String healthNotes = "a".repeat(500);
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("healthNotes", healthNotes);

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.healthNotes").value(healthNotes));

        assertThat(onlyPatientOf(appUserId).healthNotes()).isEqualTo(healthNotes);
    }

    // User decision 2026-11-24 (B3a review round 1): health notes are trimmed.
    @Test
    void trimsTheHealthNotes() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("healthNotes", "  " + SURESH_HEALTH_NOTES + "  ");

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.healthNotes").value(SURESH_HEALTH_NOTES));

        assertThat(onlyPatientOf(appUserId).healthNotes()).isEqualTo(SURESH_HEALTH_NOTES);
    }

    // The 500 limit counts the trimmed notes.
    @Test
    void acceptsHealthNotesOf500CharactersWithSurroundingSpaces() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        String healthNotes = "a".repeat(500);
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("healthNotes", "   " + healthNotes + "   ");

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.healthNotes").value(healthNotes));

        assertThat(onlyPatientOf(appUserId).healthNotes()).isEqualTo(healthNotes);
    }

    // User decision 2026-11-24 (B3a review round 1): blank health notes are no health notes.
    @ParameterizedTest
    @ValueSource(strings = {"", "   "})
    void blankHealthNotesAreSavedAsNull(String healthNotes) throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("healthNotes", healthNotes);

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.healthNotes").value(nullValue()));

        assertThat(onlyPatientOf(appUserId).healthNotes()).isNull();
    }

    @ParameterizedTest
    @ValueSource(ints = {501, 2000})
    void rejectsInvalidHealthNotes(int length) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("healthNotes", "a".repeat(length));

        assertRejected(patientBody(patientFields), "healthNotes");
    }

    @Test
    void savesWithoutHealthNotes() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.remove("healthNotes");

        postPatient(patientBody(patientFields))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.healthNotes").value(nullValue()));

        assertThat(onlyPatientOf(appUserId).healthNotes()).isNull();
    }

    // Jackson rejects a value outside the enum before Bean Validation runs, so it is MALFORMED_REQUEST.
    @ParameterizedTest
    @MethodSource("unknownEnumValues")
    void rejectsUnknownEnumValues(String field, String value) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put(field, value);

        assertApiError(postPatient(patientBody(patientFields)), 400, "MALFORMED_REQUEST");

        assertThat(testDb.count("patients")).isZero();
    }

    static Stream<Arguments> unknownEnumValues() {
        return Stream.of(
                Arguments.of("relation", "BROTHER"),
                Arguments.of("relation", "father"),
                Arguments.of("sex", "M"),
                Arguments.of("mobility", "Walks on own"),
                Arguments.of("mobility", "wheelchair"));
    }

    // Scenario (06): Adding another family member. OQ-19: POST is not idempotent on the server.
    @Test
    void eachSaveAddsAnotherPatient() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        postPatient(patientBody(sureshFields())).andExpect(status().isCreated());

        postPatient(patientBody(lataSharmaFields())).andExpect(status().isCreated());

        assertThat(testDb.patientsOf(appUserId))
                .extracting(PatientRow::fullName)
                .containsExactlyInAnyOrder(SURESH, LATA_SHARMA);
    }

    // The owner is always the caller's app_users row; an owner id in the body is ignored.
    @Test
    void ownerIsNeverTakenFromTheBody() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID someoneElsesAppUserId = givenSomeoneElseWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("userId", someoneElsesAppUserId.toString());

        postPatient(patientBody(patientFields)).andExpect(status().isCreated());

        assertThat(testDb.patientsOf(appUserId)).hasSize(1);
        assertThat(testDb.patientsOf(someoneElsesAppUserId)).isEmpty();
    }

    // The User role is chosen but Screen 04 was never saved, so there is no app_users row to link to.
    @Test
    void postWithoutAnAppUserIsAppUserNotFound() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        assertApiError(postPatient(patientBody(sureshFields())), 404, "APP_USER_NOT_FOUND");

        assertThat(testDb.count("patients")).isZero();
    }

    // Someone else's saved profile is not the caller's: still no app_users row of their own.
    @Test
    void postWithOnlySomeoneElsesAppUserIsAppUserNotFound() throws Exception {
        UUID someoneElsesAppUserId = givenSomeoneElseWithASavedProfile();
        testDb.insertProfile(userId, PHONE, "USER");

        assertApiError(postPatient(patientBody(sureshFields())), 404, "APP_USER_NOT_FOUND");

        assertThat(testDb.patientsOf(someoneElsesAppUserId)).isEmpty();
    }

    // Signed in but no profiles row yet (no role chosen), so the caller has no USER role.
    @Test
    void postWithoutAProfileIsAccessDenied() throws Exception {
        assertApiError(postPatient(patientBody(sureshFields())), 403, "ACCESS_DENIED");

        assertThat(testDb.count("patients")).isZero();
    }

    // An app_users row is seeded so a 403 here cannot be the 404 of a missing row.
    @Test
    void caretakerCannotCreatePatients() throws Exception {
        testDb.insertProfile(userId, PHONE, "CARETAKER");
        testDb.insertAppUser(userId, RAHUL, "MALE", 34, RAHUL_ADDRESS);

        assertApiError(postPatient(patientBody(sureshFields())), 403, "ACCESS_DENIED");

        assertThat(testDb.count("patients")).isZero();
    }

    @Test
    void userWhoIsAlsoACaretakerCanCreatePatients() throws Exception {
        testDb.insertProfile(userId, PHONE, "CARETAKER", "USER");
        UUID appUserId = testDb.insertAppUser(userId, RAHUL, "MALE", 34, RAHUL_ADDRESS);

        postPatient(patientBody(sureshFields())).andExpect(status().isCreated());

        assertThat(testDb.patientsOf(appUserId)).hasSize(1);
    }

    @Test
    void postNeedsAToken() throws Exception {
        givenAUserWithASavedProfile();
        MockHttpServletRequestBuilder mockHttpServletRequestBuilder = post(PATIENTS_PATH)
                .contentType(MediaType.APPLICATION_JSON)
                .content(patientBody(sureshFields()));

        assertApiError(mockMvc.perform(mockHttpServletRequestBuilder), 401, "UNAUTHENTICATED");

        assertThat(testDb.count("patients")).isZero();
    }

    // ---- GET /api/v1/patients ----

    // Scenario (06): Linked family member is listed with all details
    @Test
    void listsAPatientWithAllDetails() throws Exception {
        givenAUserWithASavedProfile();
        String patientResponseBody = postPatient(patientBody(lataIyerFields()))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        listPatients()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].id").value(idOf(patientResponseBody)))
                .andExpect(jsonPath("$.items[0].relation").value("MOTHER"))
                .andExpect(jsonPath("$.items[0].fullName").value(LATA_IYER))
                .andExpect(jsonPath("$.items[0].age").value(72))
                .andExpect(jsonPath("$.items[0].sex").value("FEMALE"))
                .andExpect(jsonPath("$.items[0].mobile.countryCode").value(INDIA_COUNTRY_CODE))
                .andExpect(jsonPath("$.items[0].mobile.number").value(LATA_IYER_MOBILE))
                .andExpect(jsonPath("$.items[0].livesAtUserAddress").value(false))
                .andExpect(jsonPath("$.items[0].address").value(LATA_IYER_ADDRESS))
                .andExpect(jsonPath("$.items[0].mobility").value("AMBULATORY"))
                .andExpect(jsonPath("$.items[0].healthNotes").value(nullValue()));
    }

    // Scenario (06): Adding another family member -> "2 patient cards in the order they were added"
    @Test
    void listsPatientsInTheOrderAdded() throws Exception {
        givenAUserWithASavedProfile();
        postPatient(patientBody(sureshFields())).andExpect(status().isCreated());
        mutableClock.advance(Duration.ofMinutes(1));
        postPatient(patientBody(lataSharmaFields())).andExpect(status().isCreated());

        listPatients()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(2)))
                .andExpect(jsonPath("$.items[0].fullName").value(SURESH))
                .andExpect(jsonPath("$.items[1].fullName").value(LATA_SHARMA))
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(20))
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.totalPages").value(1));
    }

    // Stored newest first, so only ordering by when each was added gives this order.
    @Test
    void listOrdersByWhenEachPatientWasAdded() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Instant firstAddedAt = MutableClock.DEFAULT_INSTANT;
        testDb.insertPatient(appUserId, "Third Added", true, RAHUL_ADDRESS, firstAddedAt.plus(Duration.ofDays(2)));
        testDb.insertPatient(appUserId, "Second Added", true, RAHUL_ADDRESS, firstAddedAt.plus(Duration.ofDays(1)));
        testDb.insertPatient(appUserId, "First Added", true, RAHUL_ADDRESS, firstAddedAt);

        listPatients()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].fullName").value("First Added"))
                .andExpect(jsonPath("$.items[1].fullName").value("Second Added"))
                .andExpect(jsonPath("$.items[2].fullName").value("Third Added"));
    }

    @Test
    void listPagesWithPageAndSize() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Instant firstAddedAt = MutableClock.DEFAULT_INSTANT;
        testDb.insertPatient(appUserId, "First Added", true, RAHUL_ADDRESS, firstAddedAt);
        testDb.insertPatient(appUserId, "Second Added", true, RAHUL_ADDRESS, firstAddedAt.plus(Duration.ofDays(1)));
        testDb.insertPatient(appUserId, "Third Added", true, RAHUL_ADDRESS, firstAddedAt.plus(Duration.ofDays(2)));

        mockMvc.perform(get(PATIENTS_PATH)
                        .param("page", "1")
                        .param("size", "2")
                        .header("Authorization", callerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].fullName").value("Third Added"))
                .andExpect(jsonPath("$.page").value(1))
                .andExpect(jsonPath("$.size").value(2))
                .andExpect(jsonPath("$.totalElements").value(3))
                .andExpect(jsonPath("$.totalPages").value(2));
    }

    // Review B3a round 1, MINOR 9: the family list is always in the order added; a client sort is ignored.
    @Test
    void listIgnoresAClientSort() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Instant firstAddedAt = MutableClock.DEFAULT_INSTANT;
        testDb.insertPatient(appUserId, "First Added", true, RAHUL_ADDRESS, firstAddedAt);
        testDb.insertPatient(appUserId, "Second Added", true, RAHUL_ADDRESS, firstAddedAt.plus(Duration.ofDays(1)));
        testDb.insertPatient(appUserId, "Third Added", true, RAHUL_ADDRESS, firstAddedAt.plus(Duration.ofDays(2)));

        mockMvc.perform(get(PATIENTS_PATH)
                        .param("sort", "fullName,desc")
                        .header("Authorization", callerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].fullName").value("First Added"))
                .andExpect(jsonPath("$.items[1].fullName").value("Second Added"))
                .andExpect(jsonPath("$.items[2].fullName").value("Third Added"));
    }

    // backend-code.md, API: default page size 20, max 100.
    @Test
    void listCapsThePageSizeAt100() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        testDb.insertPatient(appUserId, SURESH, true, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);

        mockMvc.perform(get(PATIENTS_PATH)
                        .param("size", "500")
                        .header("Authorization", callerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.size").value(100));
    }

    // Review B3a round 1, MINOR 7: soft-deleted patients are not part of the family.
    @Test
    void listLeavesOutDeletedPatients() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Instant addedAt = MutableClock.DEFAULT_INSTANT;
        testDb.insertPatient(appUserId, SURESH, true, RAHUL_ADDRESS, addedAt);
        UUID deletedPatientId = testDb.insertPatient(
                appUserId, LATA_SHARMA, true, RAHUL_ADDRESS, addedAt.plus(Duration.ofDays(1)));
        testDb.softDeletePatient(deletedPatientId, addedAt.plus(Duration.ofDays(2)));

        listPatients()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].fullName").value(SURESH))
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    void listIsEmptyWithoutPatients() throws Exception {
        givenAUserWithASavedProfile();

        listPatients()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(0)))
                .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    void listNeverIncludesSomeoneElsesPatients() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID someoneElsesAppUserId = givenSomeoneElseWithASavedProfile();
        testDb.insertPatient(someoneElsesAppUserId, LATA_IYER, true, PRIYA_ADDRESS, MutableClock.DEFAULT_INSTANT);
        testDb.insertPatient(appUserId, SURESH, true, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);

        listPatients()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].fullName").value(SURESH))
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    void listWithOnlySomeoneElsesPatientsIsEmpty() throws Exception {
        givenAUserWithASavedProfile();
        UUID someoneElsesAppUserId = givenSomeoneElseWithASavedProfile();
        testDb.insertPatient(someoneElsesAppUserId, LATA_IYER, true, PRIYA_ADDRESS, MutableClock.DEFAULT_INSTANT);

        listPatients()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(0)))
                .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    void listWithoutAnAppUserIsAppUserNotFound() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        assertApiError(listPatients(), 404, "APP_USER_NOT_FOUND");
    }

    @Test
    void listWithoutAProfileIsAccessDenied() throws Exception {
        assertApiError(listPatients(), 403, "ACCESS_DENIED");
    }

    // An app_users row with a patient is seeded so a 403 here cannot be a 404 or an empty list.
    @Test
    void caretakerCannotListPatients() throws Exception {
        testDb.insertProfile(userId, PHONE, "CARETAKER");
        UUID appUserId = testDb.insertAppUser(userId, RAHUL, "MALE", 34, RAHUL_ADDRESS);
        testDb.insertPatient(appUserId, SURESH, true, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);

        assertApiError(listPatients(), 403, "ACCESS_DENIED");
    }

    @Test
    void listNeedsAToken() throws Exception {
        assertApiError(mockMvc.perform(get(PATIENTS_PATH)), 401, "UNAUTHENTICATED");
    }

    // ---- helpers ----

    /** Background: a verified User with a saved profile at the Pune address. Returns the app_users id. */
    private UUID givenAUserWithASavedProfile() {
        testDb.insertProfile(userId, PHONE, "USER");
        return testDb.insertAppUser(userId, RAHUL, "MALE", 34, RAHUL_ADDRESS);
    }

    private UUID givenSomeoneElseWithASavedProfile() {
        UUID someoneElsesId = UUID.randomUUID();
        testDb.insertProfile(someoneElsesId, OTHER_PHONE, "USER");
        return testDb.insertAppUser(someoneElsesId, PRIYA, "FEMALE", 40, PRIYA_ADDRESS);
    }

    private void assertRejected(String patientBody, String field) throws Exception {
        assertApiError(postPatient(patientBody), 400, "VALIDATION_FAILED")
                .andExpect(jsonPath("$.fieldErrors['" + field + "']").exists());

        assertThat(testDb.count("patients")).isZero();
    }

    private PatientRow onlyPatientOf(UUID appUserId) {
        List<PatientRow> patientRows = testDb.patientsOf(appUserId);
        assertThat(patientRows).hasSize(1);
        return patientRows.get(0);
    }

    private String idOf(String patientResponseBody) {
        JsonNode patientResponse = objectMapper.readTree(patientResponseBody);
        return patientResponse.get("id").asString();
    }

    private ResultActions listPatients() throws Exception {
        return mockMvc.perform(get(PATIENTS_PATH).header("Authorization", callerToken()));
    }

    private ResultActions postPatient(String patientBody) throws Exception {
        return mockMvc.perform(post(PATIENTS_PATH)
                .header("Authorization", callerToken())
                .contentType(MediaType.APPLICATION_JSON)
                .content(patientBody));
    }

    private String callerToken() {
        return "Bearer " + testTokens.forUser(userId, PHONE);
    }

    private String patientBody(Map<String, Object> patientFields) {
        return objectMapper.writeValueAsString(patientFields);
    }

    /** Scenario: Adding a parent who lives with the user. No mobile; the address comes from the user. */
    private static Map<String, Object> sureshFields() {
        Map<String, Object> patientFields = new LinkedHashMap<>();
        patientFields.put("relation", "FATHER");
        patientFields.put("fullName", SURESH);
        patientFields.put("age", 68);
        patientFields.put("sex", "MALE");
        patientFields.put("livesAtUserAddress", true);
        patientFields.put("mobility", "WHEELCHAIR");
        patientFields.put("healthNotes", SURESH_HEALTH_NOTES);
        return patientFields;
    }

    /** Scenario: Adding a family member who lives at a different address with own mobile. No health notes. */
    private static Map<String, Object> lataIyerFields() {
        Map<String, Object> patientFields = new LinkedHashMap<>();
        patientFields.put("relation", "MOTHER");
        patientFields.put("fullName", LATA_IYER);
        patientFields.put("age", 72);
        patientFields.put("sex", "FEMALE");
        patientFields.put("mobile", mobileFields(INDIA_COUNTRY_CODE, LATA_IYER_MOBILE));
        patientFields.put("livesAtUserAddress", false);
        patientFields.put("address", LATA_IYER_ADDRESS);
        patientFields.put("mobility", "AMBULATORY");
        return patientFields;
    }

    /** Scenario (06): Adding another family member: "Lata Sharma", "Mother", age 65, "Female", "Walks on own". */
    private static Map<String, Object> lataSharmaFields() {
        Map<String, Object> patientFields = new LinkedHashMap<>();
        patientFields.put("relation", "MOTHER");
        patientFields.put("fullName", LATA_SHARMA);
        patientFields.put("age", 65);
        patientFields.put("sex", "FEMALE");
        patientFields.put("livesAtUserAddress", true);
        patientFields.put("mobility", "AMBULATORY");
        return patientFields;
    }

    /** A MobileNumber body; a null argument is sent as JSON null. */
    private static Map<String, Object> mobileFields(String countryCode, String number) {
        Map<String, Object> mobileFields = new LinkedHashMap<>();
        mobileFields.put("countryCode", countryCode);
        mobileFields.put("number", number);
        return mobileFields;
    }
}
