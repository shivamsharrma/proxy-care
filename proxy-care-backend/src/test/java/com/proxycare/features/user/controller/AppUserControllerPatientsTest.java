package com.proxycare.features.user.controller;

import static com.proxycare.support.ApiErrorAssert.assertApiError;
import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.AppUserRow;
import com.proxycare.support.IntegrationTest;
import com.proxycare.support.MutableClock;
import com.proxycare.support.PatientRow;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
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
import tools.jackson.databind.JsonNode;

/**
 * 05_add_family_member.feature (Screen 05) and 06_family_linked.feature (Screen 06): the patients list of
 * GET / POST / PUT /api/v1/users/me. The list in the body is synced to the patients table: an entry with an id
 * updates that patient, one without an id adds a patient, and a live patient left out is soft-deleted.
 */
class AppUserControllerPatientsTest extends IntegrationTest {

    private static final String PHONE = "+919876543210";
    private static final String OTHER_PHONE = "+919800000000";
    private static final String ME_PATH = "/api/v1/users/me";

    private static final String RAHUL = "Rahul Sharma";
    private static final String RAHUL_ADDRESS = "Flat 12, Sunrise Apartments, Kothrud, Pune 411038";
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
    private static final String RAHUL_IN_HINDI = "राहुल शर्मा";
    /** "Zaid" in Devanagari, with a nukta. */
    private static final String ZAID_WITH_NUKTA = "ज़ैद";
    /** "Chand" in Devanagari, with a candrabindu. */
    private static final String CHAND_WITH_CANDRABINDU = "चाँद";
    /** "Rahul" in Devanagari followed by the Devanagari digits 1 2 3. */
    private static final String RAHUL_WITH_DEVANAGARI_DIGITS = "राहुल१२३";
    /** Two aa vowel signs with no letter. */
    private static final String ONLY_VOWEL_SIGNS = "ाा";
    /** The Om sign twice, separated by a space. */
    private static final String OM_TWICE = "ॐ ॐ";

    private final UUID userId = UUID.randomUUID();

    // ---- adding patients ----

    // Scenario: Adding a parent who lives with the user
    @Test
    void addsAPatient() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();

        String appUserResponseBody = putPatients(sureshFields())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value(RAHUL))
                .andExpect(jsonPath("$.phone").doesNotExist())
                .andExpect(jsonPath("$.patients", hasSize(1)))
                .andExpect(jsonPath("$.patients[0].id").isNotEmpty())
                .andExpect(jsonPath("$.patients[0].relation").value("FATHER"))
                .andExpect(jsonPath("$.patients[0].fullName").value(SURESH))
                .andExpect(jsonPath("$.patients[0].age").value(68))
                .andExpect(jsonPath("$.patients[0].sex").value("MALE"))
                .andExpect(jsonPath("$.patients[0].mobile").value(nullValue()))
                .andExpect(jsonPath("$.patients[0].address").value(RAHUL_ADDRESS))
                .andExpect(jsonPath("$.patients[0].mobilityCategory").value("WHEELCHAIR"))
                .andExpect(jsonPath("$.patients[0].healthNotes").value(SURESH_HEALTH_NOTES))
                .andExpect(jsonPath("$.patients[0].mobility").doesNotExist())
                .andExpect(jsonPath("$.patients[0].livesAtUserAddress").doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();

        PatientRow patientRow = onlyPatientOf(appUserId);
        assertThat(patientRow.id()).hasToString(patientIdOf(appUserResponseBody, 0));
        assertThat(patientRow.relation()).isEqualTo("FATHER");
        assertThat(patientRow.fullName()).isEqualTo(SURESH);
        assertThat(patientRow.age()).isEqualTo(68);
        assertThat(patientRow.sex()).isEqualTo("MALE");
        assertThat(patientRow.mobileCountryCode()).isNull();
        assertThat(patientRow.mobileNumber()).isNull();
        assertThat(patientRow.address()).isEqualTo(RAHUL_ADDRESS);
        assertThat(patientRow.mobilityCategory()).isEqualTo("WHEELCHAIR");
        assertThat(patientRow.healthNotes()).isEqualTo(SURESH_HEALTH_NOTES);
        assertThat(patientRow.deletedAt()).isNull();
    }

    // Scenario: Adding a family member who lives at a different address with own mobile
    @Test
    void addsAPatientAtItsOwnAddressWithMobile() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();

        putPatients(lataIyerFields())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].relation").value("MOTHER"))
                .andExpect(jsonPath("$.patients[0].fullName").value(LATA_IYER))
                .andExpect(jsonPath("$.patients[0].age").value(72))
                .andExpect(jsonPath("$.patients[0].sex").value("FEMALE"))
                .andExpect(jsonPath("$.patients[0].mobile.countryCode").value(INDIA_COUNTRY_CODE))
                .andExpect(jsonPath("$.patients[0].mobile.number").value(LATA_IYER_MOBILE))
                .andExpect(jsonPath("$.patients[0].address").value(LATA_IYER_ADDRESS))
                .andExpect(jsonPath("$.patients[0].mobilityCategory").value("AMBULATORY"))
                .andExpect(jsonPath("$.patients[0].healthNotes").value(nullValue()));

        PatientRow patientRow = onlyPatientOf(appUserId);
        assertThat(patientRow.fullName()).isEqualTo(LATA_IYER);
        assertThat(patientRow.mobileCountryCode()).isEqualTo(INDIA_COUNTRY_CODE);
        assertThat(patientRow.mobileNumber()).isEqualTo(LATA_IYER_MOBILE);
        assertThat(patientRow.address()).isEqualTo(LATA_IYER_ADDRESS);
        assertThat(patientRow.healthNotes()).isNull();
    }

    // POST takes the same body, so the user and their patients can be created together.
    @Test
    void createsTheUserWithTheirPatients() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        postPatients(sureshFields())
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.fullName").value(RAHUL))
                .andExpect(jsonPath("$.patients", hasSize(1)))
                .andExpect(jsonPath("$.patients[0].fullName").value(SURESH));

        AppUserRow appUserRow = testDb.appUserOf(userId);
        assertThat(onlyPatientOf(appUserRow.id()).fullName()).isEqualTo(SURESH);
    }

    // Scenario (06): Adding another family member -> "2 patient cards in the order they were added"
    @Test
    void addingAnotherPatientKeepsTheFirst() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID sureshId = testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);
        mutableClock.advance(Duration.ofMinutes(1));

        putPatients(withId(sureshFields(), sureshId), lataSharmaFields())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients", hasSize(2)))
                .andExpect(jsonPath("$.patients[0].id").value(sureshId.toString()))
                .andExpect(jsonPath("$.patients[0].fullName").value(SURESH))
                .andExpect(jsonPath("$.patients[1].fullName").value(LATA_SHARMA));

        assertThat(testDb.patientsOf(appUserId))
                .extracting(PatientRow::fullName)
                .containsExactly(SURESH, LATA_SHARMA);
        getAppUser()
                .andExpect(jsonPath("$.patients[0].fullName").value(SURESH))
                .andExpect(jsonPath("$.patients[1].fullName").value(LATA_SHARMA));
    }

    @Test
    void addsSeveralPatientsInOneSave() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();

        putPatients(sureshFields(), lataSharmaFields())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients", hasSize(2)));

        assertThat(testDb.patientsOf(appUserId))
                .extracting(PatientRow::fullName)
                .containsExactlyInAnyOrder(SURESH, LATA_SHARMA);
    }

    // Scenario Outline: Each mobility category is saved with the right enum
    @ParameterizedTest
    @ValueSource(strings = {"AMBULATORY", "WHEELCHAIR", "BEDRIDDEN"})
    void savesEachMobilityCategory(String mobilityCategory) throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("mobilityCategory", mobilityCategory);

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].mobilityCategory").value(mobilityCategory));

        assertThat(onlyPatientOf(appUserId).mobilityCategory()).isEqualTo(mobilityCategory);
    }

    // Scenario Outline: Each relation is saved with the right enum
    @ParameterizedTest
    @ValueSource(strings = {"FATHER", "MOTHER", "SPOUSE", "GRANDPARENT", "SIBLING", "OTHER"})
    void savesEachRelation(String relation) throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("relation", relation);

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].relation").value(relation));

        assertThat(onlyPatientOf(appUserId).relation()).isEqualTo(relation);
    }

    @ParameterizedTest
    @ValueSource(strings = {"FEMALE", "MALE", "OTHER"})
    void savesEachSex(String sex) throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("sex", sex);

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].sex").value(sex));

        assertThat(onlyPatientOf(appUserId).sex()).isEqualTo(sex);
    }

    // The owner is always the caller's app_users row; an owner id in a patient entry is ignored.
    @Test
    void ownerIsNeverTakenFromTheBody() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID someoneElsesAppUserId = givenSomeoneElseWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("userId", someoneElsesAppUserId.toString());

        putPatients(patientFields).andExpect(status().isOk());

        assertThat(testDb.patientsOf(appUserId)).hasSize(1);
        assertThat(testDb.patientsOf(someoneElsesAppUserId)).isEmpty();
    }

    // ---- editing and removing patients ----

    // Scenario (06): Editing a linked family member -> "no new patient should be created"
    @Test
    void editsAPatientInPlace() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID sureshId = testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);
        Map<String, Object> patientFields = withId(sureshFields(), sureshId);
        patientFields.put("mobilityCategory", "BEDRIDDEN");

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients", hasSize(1)))
                .andExpect(jsonPath("$.patients[0].id").value(sureshId.toString()))
                .andExpect(jsonPath("$.patients[0].mobilityCategory").value("BEDRIDDEN"));

        PatientRow patientRow = onlyPatientOf(appUserId);
        assertThat(patientRow.id()).isEqualTo(sureshId);
        assertThat(patientRow.mobilityCategory()).isEqualTo("BEDRIDDEN");
        assertThat(patientRow.healthNotes()).isEqualTo(SURESH_HEALTH_NOTES);
    }

    // An edit is a full replace of the patient: optional fields left out are cleared.
    @Test
    void editingWithoutOptionalFieldsClearsThem() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        String appUserResponseBody = putPatients(lataIyerFields()).andReturn().getResponse().getContentAsString();
        UUID lataId = UUID.fromString(patientIdOf(appUserResponseBody, 0));
        Map<String, Object> patientFields = withId(lataIyerFields(), lataId);
        patientFields.remove("mobile");

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].mobile").value(nullValue()));

        PatientRow patientRow = onlyPatientOf(appUserId);
        assertThat(patientRow.mobileCountryCode()).isNull();
        assertThat(patientRow.mobileNumber()).isNull();
    }

    // User decision 2026-11-25: a live patient left out of the list is soft-deleted, not removed.
    @Test
    void patientLeftOutOfTheListIsSoftDeleted() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID sureshId = testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);
        UUID lataId = testDb.insertPatient(appUserId, LATA_SHARMA, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);

        putPatients(withId(sureshFields(), sureshId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients", hasSize(1)))
                .andExpect(jsonPath("$.patients[0].id").value(sureshId.toString()));

        // @SoftDelete (user decision 2026-11-26) stamps deleted_at with the database time, not the app Clock.
        assertThat(testDb.patient(lataId).deletedAt()).isNotNull();
        assertThat(testDb.patient(sureshId).deletedAt()).isNull();
        getAppUser()
                .andExpect(jsonPath("$.patients", hasSize(1)))
                .andExpect(jsonPath("$.patients[0].fullName").value(SURESH));
    }

    @Test
    void anEmptyListSoftDeletesEveryPatient() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);
        testDb.insertPatient(appUserId, LATA_SHARMA, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);

        putPatients().andExpect(status().isOk()).andExpect(jsonPath("$.patients", hasSize(0)));

        assertThat(testDb.patientsOf(appUserId)).hasSize(2).allSatisfy(patientRow ->
                assertThat(patientRow.deletedAt()).isNotNull());
    }

    // A patient already soft-deleted keeps its first deleted_at.
    @Test
    void anAlreadyDeletedPatientStaysAsItWas() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID deletedPatientId = testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);
        Instant deletedAt = MutableClock.DEFAULT_INSTANT.plus(Duration.ofMinutes(5));
        testDb.softDeletePatient(deletedPatientId, deletedAt);
        mutableClock.advance(Duration.ofDays(1));

        putPatients().andExpect(status().isOk());

        assertThat(testDb.patient(deletedPatientId).deletedAt()).isEqualTo(deletedAt);
    }

    @Test
    void unknownPatientIdIsPatientNotFound() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID sureshId = testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);
        Map<String, Object> appUserFields = appUserFields(
                PRIYA, List.of(withId(lataSharmaFields(), UUID.randomUUID())));

        assertApiError(putAppUser(appUserFields), 404, "PATIENT_NOT_FOUND");

        assertNothingChanged(appUserId, sureshId);
    }

    // Someone else's patient is a 404, never theirs to edit.
    @Test
    void someoneElsesPatientIdIsPatientNotFound() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID sureshId = testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);
        UUID someoneElsesAppUserId = givenSomeoneElseWithASavedProfile();
        UUID someoneElsesPatientId =
                testDb.insertPatient(someoneElsesAppUserId, LATA_IYER, PRIYA_ADDRESS, MutableClock.DEFAULT_INSTANT);
        Map<String, Object> appUserFields = appUserFields(
                PRIYA, List.of(withId(sureshFields(), sureshId), withId(lataSharmaFields(), someoneElsesPatientId)));

        assertApiError(putAppUser(appUserFields), 404, "PATIENT_NOT_FOUND");

        assertNothingChanged(appUserId, sureshId);
        PatientRow someoneElsesPatientRow = testDb.patient(someoneElsesPatientId);
        assertThat(someoneElsesPatientRow.userId()).isEqualTo(someoneElsesAppUserId);
        assertThat(someoneElsesPatientRow.fullName()).isEqualTo(LATA_IYER);
        assertThat(someoneElsesPatientRow.deletedAt()).isNull();
    }

    // A deleted patient is not part of the family any more, so it can't be edited back.
    @Test
    void deletedPatientIdIsPatientNotFound() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID deletedPatientId = testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);
        testDb.softDeletePatient(deletedPatientId, MutableClock.DEFAULT_INSTANT);

        assertApiError(putPatients(withId(sureshFields(), deletedPatientId)), 404, "PATIENT_NOT_FOUND");

        assertThat(testDb.patientsOf(appUserId)).singleElement().satisfies(patientRow ->
                assertThat(patientRow.deletedAt()).isEqualTo(MutableClock.DEFAULT_INSTANT));
    }

    // POST has no patients yet, so any id there is unknown.
    @Test
    void createWithAPatientIdIsPatientNotFound() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        assertApiError(postPatients(withId(sureshFields(), UUID.randomUUID())), 404, "PATIENT_NOT_FOUND");

        assertThat(testDb.count("app_users")).isZero();
        assertThat(testDb.count("patients")).isZero();
    }

    @Test
    void duplicatePatientIdsAreRejected() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID sureshId = testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);

        assertApiError(putPatients(withId(sureshFields(), sureshId), withId(lataSharmaFields(), sureshId)),
                        400, "VALIDATION_FAILED")
                .andExpect(jsonPath("$.fieldErrors.patients").exists());

        assertThat(onlyPatientOf(appUserId).fullName()).isEqualTo(SURESH);
    }

    // PUT is a full replace, so an omitted list is an error rather than "delete every patient".
    @Test
    void missingPatientsListIsRejected() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);
        Map<String, Object> appUserFields = appUserFields(RAHUL, List.of());
        appUserFields.remove("patients");

        assertApiError(putAppUser(appUserFields), 400, "VALIDATION_FAILED")
                .andExpect(jsonPath("$.fieldErrors.patients").exists());

        assertThat(onlyPatientOf(appUserId).deletedAt()).isNull();
    }

    @Test
    void createWithoutAPatientsListIsRejected() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");
        Map<String, Object> appUserFields = appUserFields(RAHUL, List.of());
        appUserFields.remove("patients");

        assertApiError(postAppUser(appUserFields), 400, "VALIDATION_FAILED")
                .andExpect(jsonPath("$.fieldErrors.patients").exists());

        assertThat(testDb.count("app_users")).isZero();
    }

    @Test
    void nullPatientEntryIsRejected() throws Exception {
        givenAUserWithASavedProfile();
        List<Object> patients = new ArrayList<>();
        patients.add(null);

        assertRejected(appUserFields(RAHUL, patients), "patients[0]");
    }

    // An invalid patient fails the whole save: the user fields are not applied either.
    @Test
    void invalidPatientLeavesEverythingUnchanged() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID sureshId = testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);
        Map<String, Object> invalidPatientFields = lataSharmaFields();
        invalidPatientFields.put("age", 121);

        assertApiError(putAppUser(appUserFields(PRIYA, List.of(invalidPatientFields))), 400, "VALIDATION_FAILED")
                .andExpect(jsonPath("$.fieldErrors['patients[0].age']").exists());

        assertNothingChanged(appUserId, sureshId);
    }

    // ---- patient field validation ----

    // Scenario Outline: Missing required fields block saving (Relation, Full name, Age, Sex, Address, Mobility)
    @ParameterizedTest
    @ValueSource(strings = {"relation", "fullName", "age", "sex", "address", "mobilityCategory"})
    void rejectsAMissingRequiredField(String field) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.remove(field);

        assertPatientRejected(patientFields, field);
    }

    // User decision 2026-11-24: same name rule as the user name (B2), length 2-80, trimmed.
    @Test
    void trimsTheFullName() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("fullName", "  " + SURESH + "  ");

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].fullName").value(SURESH));

        assertThat(onlyPatientOf(appUserId).fullName()).isEqualTo(SURESH);
    }

    @ParameterizedTest
    @MethodSource("validFullNames")
    void acceptsValidFullNames(String fullName) throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("fullName", fullName);

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].fullName").value(fullName.trim()));

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

        assertPatientRejected(patientFields, "fullName");
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

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].age").value(age));

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

        assertPatientRejected(patientFields, "age");
    }

    // Review B3a rounds 1-2: age is a whole number; a JSON fraction (even 68.0) is never coerced, and
    // Jackson rejects it before Bean Validation runs, so it is MALFORMED_REQUEST.
    @ParameterizedTest
    @ValueSource(doubles = {68.5, 68.0})
    void rejectsAFractionalAge(double age) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("age", age);

        assertApiError(putPatients(patientFields), 400, "MALFORMED_REQUEST");

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

        assertPatientRejected(patientFields, field);
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

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].mobile").value(nullValue()));

        PatientRow patientRow = onlyPatientOf(appUserId);
        assertThat(patientRow.mobileCountryCode()).isNull();
        assertThat(patientRow.mobileNumber()).isNull();
    }

    @Test
    void savesWithAnExplicitlyNullMobile() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("mobile", null);

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].mobile").value(nullValue()));

        PatientRow patientRow = onlyPatientOf(appUserId);
        assertThat(patientRow.mobileCountryCode()).isNull();
        assertThat(patientRow.mobileNumber()).isNull();
    }

    // Scenario Outline: Missing required fields block saving (Address)
    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = {"   "})
    void rejectsMissingOrBlankAddress(String address) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("address", address);

        assertPatientRejected(patientFields, "address");
    }

    // Same limit as the user address (B2).
    @Test
    void rejectsAnAddressLongerThan300Characters() throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("address", "a".repeat(301));

        assertPatientRejected(patientFields, "address");
    }

    @Test
    void acceptsAnAddressOfExactly300Characters() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        String address = "a".repeat(300);
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("address", address);

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].address").value(address));

        assertThat(onlyPatientOf(appUserId).address()).isEqualTo(address);
    }

    // User decision 2026-11-24 (B3a review round 1): the address is trimmed.
    @Test
    void trimsTheAddress() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("address", "  " + LATA_IYER_ADDRESS + "  ");

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].address").value(LATA_IYER_ADDRESS));

        assertThat(onlyPatientOf(appUserId).address()).isEqualTo(LATA_IYER_ADDRESS);
    }

    // The 300 limit counts the trimmed address.
    @Test
    void acceptsAnAddressOf300CharactersWithSurroundingSpaces() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        String address = "a".repeat(300);
        Map<String, Object> patientFields = lataIyerFields();
        patientFields.put("address", "   " + address + "   ");

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].address").value(address));

        assertThat(onlyPatientOf(appUserId).address()).isEqualTo(address);
    }

    // Scenario: Health notes character limit (ASSUMPTION: max 500 chars)
    @Test
    void acceptsHealthNotesOfExactly500Characters() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        String healthNotes = "a".repeat(500);
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("healthNotes", healthNotes);

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].healthNotes").value(healthNotes));

        assertThat(onlyPatientOf(appUserId).healthNotes()).isEqualTo(healthNotes);
    }

    // User decision 2026-11-24 (B3a review round 1): health notes are trimmed.
    @Test
    void trimsTheHealthNotes() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("healthNotes", "  " + SURESH_HEALTH_NOTES + "  ");

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].healthNotes").value(SURESH_HEALTH_NOTES));

        assertThat(onlyPatientOf(appUserId).healthNotes()).isEqualTo(SURESH_HEALTH_NOTES);
    }

    // The 500 limit counts the trimmed notes.
    @Test
    void acceptsHealthNotesOf500CharactersWithSurroundingSpaces() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        String healthNotes = "a".repeat(500);
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("healthNotes", "   " + healthNotes + "   ");

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].healthNotes").value(healthNotes));

        assertThat(onlyPatientOf(appUserId).healthNotes()).isEqualTo(healthNotes);
    }

    // User decision 2026-11-24 (B3a review round 1): blank health notes are no health notes.
    @ParameterizedTest
    @ValueSource(strings = {"", "   "})
    void blankHealthNotesAreSavedAsNull(String healthNotes) throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("healthNotes", healthNotes);

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].healthNotes").value(nullValue()));

        assertThat(onlyPatientOf(appUserId).healthNotes()).isNull();
    }

    @ParameterizedTest
    @ValueSource(ints = {501, 2000})
    void rejectsInvalidHealthNotes(int length) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put("healthNotes", "a".repeat(length));

        assertPatientRejected(patientFields, "healthNotes");
    }

    @Test
    void savesWithoutHealthNotes() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.remove("healthNotes");

        putPatients(patientFields)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].healthNotes").value(nullValue()));

        assertThat(onlyPatientOf(appUserId).healthNotes()).isNull();
    }

    // Jackson rejects a value outside the enum before Bean Validation runs, so it is MALFORMED_REQUEST.
    @ParameterizedTest
    @MethodSource("unknownEnumValues")
    void rejectsUnknownEnumValues(String field, String value) throws Exception {
        givenAUserWithASavedProfile();
        Map<String, Object> patientFields = sureshFields();
        patientFields.put(field, value);

        assertApiError(putPatients(patientFields), 400, "MALFORMED_REQUEST");

        assertThat(testDb.count("patients")).isZero();
    }

    static Stream<Arguments> unknownEnumValues() {
        return Stream.of(
                Arguments.of("relation", "BROTHER"),
                Arguments.of("relation", "father"),
                Arguments.of("sex", "M"),
                Arguments.of("mobilityCategory", "Walks on own"),
                Arguments.of("mobilityCategory", "wheelchair"));
    }

    // ---- GET /api/v1/users/me ----

    // Scenario (06): Linked family member is listed with all details
    @Test
    void returnsThePatientsWithAllDetails() throws Exception {
        givenAUserWithASavedProfile();
        String appUserResponseBody = putPatients(lataIyerFields()).andReturn().getResponse().getContentAsString();

        getAppUser()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value(RAHUL))
                .andExpect(jsonPath("$.patients", hasSize(1)))
                .andExpect(jsonPath("$.patients[0].id").value(patientIdOf(appUserResponseBody, 0)))
                .andExpect(jsonPath("$.patients[0].relation").value("MOTHER"))
                .andExpect(jsonPath("$.patients[0].fullName").value(LATA_IYER))
                .andExpect(jsonPath("$.patients[0].age").value(72))
                .andExpect(jsonPath("$.patients[0].sex").value("FEMALE"))
                .andExpect(jsonPath("$.patients[0].mobile.countryCode").value(INDIA_COUNTRY_CODE))
                .andExpect(jsonPath("$.patients[0].mobile.number").value(LATA_IYER_MOBILE))
                .andExpect(jsonPath("$.patients[0].address").value(LATA_IYER_ADDRESS))
                .andExpect(jsonPath("$.patients[0].mobilityCategory").value("AMBULATORY"))
                .andExpect(jsonPath("$.patients[0].healthNotes").value(nullValue()));
    }

    // Stored newest first, so only ordering by when each was added gives this order.
    @Test
    void listsPatientsInTheOrderAdded() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Instant firstAddedAt = MutableClock.DEFAULT_INSTANT;
        testDb.insertPatient(appUserId, "Third Added", RAHUL_ADDRESS, firstAddedAt.plus(Duration.ofDays(2)));
        testDb.insertPatient(appUserId, "Second Added", RAHUL_ADDRESS, firstAddedAt.plus(Duration.ofDays(1)));
        testDb.insertPatient(appUserId, "First Added", RAHUL_ADDRESS, firstAddedAt);

        getAppUser()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients[0].fullName").value("First Added"))
                .andExpect(jsonPath("$.patients[1].fullName").value("Second Added"))
                .andExpect(jsonPath("$.patients[2].fullName").value("Third Added"));
    }

    // Review B3a round 1, MINOR 7: soft-deleted patients are not part of the family.
    @Test
    void leavesOutDeletedPatients() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        Instant addedAt = MutableClock.DEFAULT_INSTANT;
        testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, addedAt);
        UUID deletedPatientId =
                testDb.insertPatient(appUserId, LATA_SHARMA, RAHUL_ADDRESS, addedAt.plus(Duration.ofDays(1)));
        testDb.softDeletePatient(deletedPatientId, addedAt.plus(Duration.ofDays(2)));

        getAppUser()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients", hasSize(1)))
                .andExpect(jsonPath("$.patients[0].fullName").value(SURESH));
    }

    @Test
    void neverIncludesSomeoneElsesPatients() throws Exception {
        UUID appUserId = givenAUserWithASavedProfile();
        UUID someoneElsesAppUserId = givenSomeoneElseWithASavedProfile();
        testDb.insertPatient(someoneElsesAppUserId, LATA_IYER, PRIYA_ADDRESS, MutableClock.DEFAULT_INSTANT);
        testDb.insertPatient(appUserId, SURESH, RAHUL_ADDRESS, MutableClock.DEFAULT_INSTANT);

        getAppUser()
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patients", hasSize(1)))
                .andExpect(jsonPath("$.patients[0].fullName").value(SURESH));
    }

    @Test
    void savingNeverChangesSomeoneElsesPatients() throws Exception {
        givenAUserWithASavedProfile();
        UUID someoneElsesAppUserId = givenSomeoneElseWithASavedProfile();
        UUID someoneElsesPatientId =
                testDb.insertPatient(someoneElsesAppUserId, LATA_IYER, PRIYA_ADDRESS, MutableClock.DEFAULT_INSTANT);

        putPatients().andExpect(status().isOk());

        assertThat(testDb.patient(someoneElsesPatientId).deletedAt()).isNull();
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

    private void assertPatientRejected(Map<String, Object> patientFields, String field) throws Exception {
        assertRejected(appUserFields(RAHUL, List.of(patientFields)), "patients[0]." + field);
    }

    private void assertRejected(Map<String, Object> appUserFields, String field) throws Exception {
        assertApiError(putAppUser(appUserFields), 400, "VALIDATION_FAILED")
                .andExpect(jsonPath("$.fieldErrors['" + field + "']").exists());

        assertThat(testDb.count("patients")).isZero();
    }

    /** The user is still Rahul and Suresh is still their only, live patient. */
    private void assertNothingChanged(UUID appUserId, UUID sureshId) {
        assertThat(testDb.appUserOf(userId).fullName()).isEqualTo(RAHUL);
        assertThat(testDb.patientsOf(appUserId)).singleElement().satisfies(patientRow -> {
            assertThat(patientRow.id()).isEqualTo(sureshId);
            assertThat(patientRow.fullName()).isEqualTo(SURESH);
            assertThat(patientRow.deletedAt()).isNull();
        });
    }

    private PatientRow onlyPatientOf(UUID appUserId) {
        List<PatientRow> patientRows = testDb.patientsOf(appUserId);
        assertThat(patientRows).hasSize(1);
        return patientRows.get(0);
    }

    private String patientIdOf(String appUserResponseBody, int index) {
        JsonNode appUserResponse = objectMapper.readTree(appUserResponseBody);
        return appUserResponse.get("patients").get(index).get("id").asString();
    }

    private ResultActions getAppUser() throws Exception {
        return mockMvc.perform(get(ME_PATH).header("Authorization", callerToken()));
    }

    /** POST with Rahul's user fields and these patients. */
    @SafeVarargs
    private ResultActions postPatients(Map<String, Object>... patientFields) throws Exception {
        return postAppUser(appUserFields(RAHUL, Arrays.asList(patientFields)));
    }

    private ResultActions postAppUser(Map<String, Object> appUserFields) throws Exception {
        return mockMvc.perform(post(ME_PATH)
                .header("Authorization", callerToken())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(appUserFields)));
    }

    /** PUT with Rahul's user fields and these patients. */
    @SafeVarargs
    private ResultActions putPatients(Map<String, Object>... patientFields) throws Exception {
        return putAppUser(appUserFields(RAHUL, Arrays.asList(patientFields)));
    }

    private ResultActions putAppUser(Map<String, Object> appUserFields) throws Exception {
        return mockMvc.perform(put(ME_PATH)
                .header("Authorization", callerToken())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(appUserFields)));
    }

    private String callerToken() {
        return "Bearer " + testTokens.forUser(userId, PHONE);
    }

    /** A SaveAppUserRequest body; Rahul's sex, age and address, the given name and patients. */
    private static Map<String, Object> appUserFields(String fullName, List<?> patients) {
        Map<String, Object> appUserFields = new LinkedHashMap<>();
        appUserFields.put("fullName", fullName);
        appUserFields.put("sex", "MALE");
        appUserFields.put("age", 34);
        appUserFields.put("address", RAHUL_ADDRESS);
        appUserFields.put("patients", patients);
        return appUserFields;
    }

    private static Map<String, Object> withId(Map<String, Object> patientFields, UUID patientId) {
        patientFields.put("id", patientId.toString());
        return patientFields;
    }

    /** Scenario: Adding a parent who lives with the user. No mobile; the user's address typed in. */
    private static Map<String, Object> sureshFields() {
        Map<String, Object> patientFields = new LinkedHashMap<>();
        patientFields.put("relation", "FATHER");
        patientFields.put("fullName", SURESH);
        patientFields.put("age", 68);
        patientFields.put("sex", "MALE");
        patientFields.put("address", RAHUL_ADDRESS);
        patientFields.put("mobilityCategory", "WHEELCHAIR");
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
        patientFields.put("address", LATA_IYER_ADDRESS);
        patientFields.put("mobilityCategory", "AMBULATORY");
        return patientFields;
    }

    /** Scenario (06): Adding another family member: "Lata Sharma", "Mother", age 65, "Female", "Walks on own". */
    private static Map<String, Object> lataSharmaFields() {
        Map<String, Object> patientFields = new LinkedHashMap<>();
        patientFields.put("relation", "MOTHER");
        patientFields.put("fullName", LATA_SHARMA);
        patientFields.put("age", 65);
        patientFields.put("sex", "FEMALE");
        patientFields.put("address", RAHUL_ADDRESS);
        patientFields.put("mobilityCategory", "AMBULATORY");
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
