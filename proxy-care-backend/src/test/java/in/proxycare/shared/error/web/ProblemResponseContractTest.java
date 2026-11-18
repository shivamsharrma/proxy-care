package in.proxycare.shared.error.web;

import static in.proxycare.support.ApiAssertions.assertProblem;
import static in.proxycare.support.ApiAssertions.errors;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;

import in.proxycare.shared.error.ErrorCode;
import in.proxycare.shared.error.FieldValidationError;
import in.proxycare.support.IntegrationTest;
import in.proxycare.support.MutableClock;
import in.proxycare.support.TestJson;
import in.proxycare.support.security.TestUser;
import jakarta.servlet.DispatcherType;
import jakarta.servlet.RequestDispatcher;
import java.nio.charset.StandardCharsets;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;
import tools.jackson.databind.JsonNode;

/**
 * Every generic error category produces exactly the ADR 0012 problem, whichever layer raised it:
 * MVC, the security filters, the request-size filter or the container's error page. Driven through
 * the test-only probe API (support.api).
 */
@IntegrationTest
class ProblemResponseContractTest {

  private static final String PROBES = "/api/v1/probes";
  private static final String SECRET = "s3cr3t-vendor-or-sql-text";

  @Autowired private MockMvcTester mvc;

  static Stream<Arguments> applicationErrors() {
    return Stream.of(
        Arguments.of("not-found", ErrorCode.NOT_FOUND),
        Arguments.of("conflict", ErrorCode.CONFLICT),
        Arguments.of("business-rule", ErrorCode.BUSINESS_RULE_VIOLATION),
        Arguments.of("forbidden", ErrorCode.FORBIDDEN),
        Arguments.of("upstream", ErrorCode.UPSTREAM_ERROR),
        Arguments.of("upstream-timeout", ErrorCode.UPSTREAM_TIMEOUT),
        Arguments.of("raw-vendor-error", ErrorCode.UPSTREAM_ERROR),
        Arguments.of("raw-vendor-timeout", ErrorCode.UPSTREAM_TIMEOUT),
        Arguments.of("integrity", ErrorCode.CONFLICT),
        Arguments.of("optimistic", ErrorCode.CONFLICT),
        Arguments.of("db-timeout", ErrorCode.SERVICE_UNAVAILABLE),
        Arguments.of("bulkhead-full", ErrorCode.SERVICE_UNAVAILABLE),
        Arguments.of("rate-limited", ErrorCode.RATE_LIMITED),
        Arguments.of("unexpected", ErrorCode.INTERNAL_ERROR));
  }

  @ParameterizedTest(name = "{0} -> {1}")
  @MethodSource("applicationErrors")
  void mapsEveryCategoryWithoutLeakingInternals(String kind, ErrorCode expected) {
    MvcTestResult result = mvc.get().uri(PROBES + "/errors/" + kind).exchange();

    String body = assertProblemResponse(result, expected);
    assertThat(body).doesNotContain(SECRET, "Exception", "select", "java.", "in.proxycare");
  }

  @Test
  void hasExactlyTheContractFields() {
    MvcTestResult result = mvc.get().uri(PROBES + "/errors/business-rule?email=a@b.c").exchange();

    JsonNode problem = assertProblem(body(result), ErrorCode.BUSINESS_RULE_VIOLATION);
    assertThat(problem.path("detail").asString()).isEqualTo("A completed probe cannot be renamed.");
    // The path only: query strings can hold personal data.
    assertThat(problem.path("instance").asString()).isEqualTo(PROBES + "/errors/business-rule");
    assertThat(problem.path("timestamp").asString())
        .isEqualTo(MutableClock.DEFAULT_INSTANT.toString());
    assertThat(problem.has("errors")).isFalse();
  }

  @Test
  void addsRetryAfterToServiceUnavailable() {
    MvcTestResult circuitOpen = mvc.get().uri(PROBES + "/errors/circuit-open").exchange();
    assertProblemResponse(circuitOpen, ErrorCode.SERVICE_UNAVAILABLE);
    // The circuit breaker's own open-state wait.
    assertThat(circuitOpen.getResponse().getHeader(HttpHeaders.RETRY_AFTER)).isEqualTo("42");

    MvcTestResult database = mvc.get().uri(PROBES + "/errors/db-timeout").exchange();
    assertThat(database.getResponse().getHeader(HttpHeaders.RETRY_AFTER)).isEqualTo("5");
  }

  @Test
  void addsRetryAfterToRateLimiting() {
    MvcTestResult application = mvc.get().uri(PROBES + "/errors/app-rate-limited").exchange();
    assertProblemResponse(application, ErrorCode.RATE_LIMITED);
    assertThat(application.getResponse().getHeader(HttpHeaders.RETRY_AFTER)).isEqualTo("2");

    MvcTestResult resilience = mvc.get().uri(PROBES + "/errors/rate-limited").exchange();
    assertThat(resilience.getResponse().getHeader(HttpHeaders.RETRY_AFTER)).isEqualTo("5");
  }

  @Test
  void reportsConstraintViolationsAsFieldErrors() {
    JsonNode problem =
        assertProblem(
            body(mvc.get().uri(PROBES + "/errors/constraint").exchange()),
            ErrorCode.VALIDATION_ERROR);

    assertThat(errors(problem))
        .extracting(FieldValidationError::field, FieldValidationError::code)
        .containsExactlyInAnyOrder(
            tuple("name", "NotBlank"), tuple("amountPaise", "PositiveOrZero"));
  }

  // ---- Request body ---------------------------------------------------------------------------

  @Test
  void validatesTheRequestBody() {
    JsonNode problem =
        assertProblem(
            body(post("{\"name\": \"\", \"amountPaise\": -1}")), ErrorCode.VALIDATION_ERROR);

    assertThat(errors(problem))
        .extracting(FieldValidationError::field, FieldValidationError::code)
        .containsExactlyInAnyOrder(
            tuple("name", "NotBlank"), tuple("amountPaise", "PositiveOrZero"));
    assertThat(errors(problem)).allSatisfy(error -> assertThat(error.message()).isNotBlank());
  }

  @Test
  void rejectsMalformedJsonWithoutEchoingIt() {
    MvcTestResult result = post("{\"name\": " + SECRET);

    String body = assertProblemResponse(result, ErrorCode.MALFORMED_REQUEST);
    assertThat(body).doesNotContain(SECRET);
    assertThat(TestJson.tree(body).has("errors")).isFalse();
  }

  @Test
  void namesAnUnknownProperty() {
    JsonNode problem =
        assertProblem(
            body(post("{\"name\": \"a\", \"amountPaise\": 1, \"nickname\": \"x\"}")),
            ErrorCode.MALFORMED_REQUEST);

    assertThat(errors(problem))
        .containsExactly(
            new FieldValidationError("nickname", "UnknownProperty", "is not a known property"));
  }

  @Test
  void namesAValueOfTheWrongType() {
    JsonNode wrongType =
        assertProblem(
            body(post("{\"name\": \"a\", \"amountPaise\": \"ten\"}")), ErrorCode.MALFORMED_REQUEST);
    JsonNode fraction =
        assertProblem(
            body(post("{\"name\": \"a\", \"amountPaise\": 10.5}")), ErrorCode.MALFORMED_REQUEST);

    assertThat(errors(wrongType))
        .extracting(FieldValidationError::field)
        .containsExactly("amountPaise");
    assertThat(errors(fraction))
        .extracting(FieldValidationError::code)
        .containsExactly("InvalidFormat");
  }

  @Test
  void refusesBodiesOverOneMegabyte() {
    String oversized = "{\"name\": \"" + "x".repeat(1_100_000) + "\", \"amountPaise\": 1}";

    assertProblemResponse(post(oversized), ErrorCode.PAYLOAD_TOO_LARGE);
  }

  @Test
  void refusesUnsupportedContentTypes() {
    MvcTestResult result =
        mvc.post().uri(PROBES).contentType(MediaType.TEXT_PLAIN).content("name=a").exchange();

    assertProblemResponse(result, ErrorCode.UNSUPPORTED_MEDIA_TYPE);
    assertThat(result.getResponse().getHeader(HttpHeaders.ACCEPT)).contains("application/json");
  }

  @Test
  void refusesMultipart() {
    MvcTestResult result =
        mvc.post()
            .uri(PROBES)
            .contentType(MediaType.MULTIPART_FORM_DATA)
            .content("--x--")
            .exchange();

    assertProblemResponse(result, ErrorCode.UNSUPPORTED_MEDIA_TYPE);
  }

  // ---- Parameters and routing -----------------------------------------------------------------

  @Test
  void reportsAMissingParameter() {
    JsonNode problem =
        assertProblem(
            body(mvc.get().uri(PROBES + "/params").exchange()), ErrorCode.MALFORMED_REQUEST);

    assertThat(errors(problem))
        .containsExactly(
            new FieldValidationError("count", "Required", "required parameter is missing"));
  }

  @Test
  void reportsAParameterOfTheWrongType() {
    JsonNode query =
        assertProblem(
            body(mvc.get().uri(PROBES + "/params?count=" + SECRET).exchange()),
            ErrorCode.MALFORMED_REQUEST);
    JsonNode path =
        assertProblem(
            body(mvc.get().uri(PROBES + "/not-a-uuid").exchange()), ErrorCode.MALFORMED_REQUEST);

    assertThat(errors(query))
        .containsExactly(
            new FieldValidationError("count", "InvalidFormat", "has an invalid value"));
    assertThat(errors(path)).extracting(FieldValidationError::field).containsExactly("id");
  }

  @Test
  void validatesParameters() {
    JsonNode problem =
        assertProblem(
            body(mvc.get().uri(PROBES + "/params?count=50").exchange()),
            ErrorCode.VALIDATION_ERROR);

    assertThat(errors(problem))
        .extracting(FieldValidationError::field, FieldValidationError::code)
        .containsExactly(tuple("count", "Max"));
  }

  @Test
  void reportsUnknownPaths() {
    assertProblemResponse(mvc.get().uri(PROBES + "/a/b/c").exchange(), ErrorCode.NOT_FOUND);
  }

  @Test
  void reportsUnsupportedMethodsWithTheAllowedOnes() {
    MvcTestResult result = mvc.delete().uri(PROBES).exchange();

    assertProblemResponse(result, ErrorCode.METHOD_NOT_ALLOWED);
    assertThat(result.getResponse().getHeader(HttpHeaders.ALLOW)).contains("GET", "POST");
  }

  @Test
  void reportsUnacceptableRepresentations() {
    MvcTestResult result =
        mvc.get().uri(PROBES + "/params?count=1").accept(MediaType.APPLICATION_XML).exchange();

    assertProblemResponse(result, ErrorCode.NOT_ACCEPTABLE);
  }

  // ---- Security ---------------------------------------------------------------------------------

  @Test
  void securityFiltersAnswerAnonymousCallersWith401() {
    MvcTestResult result = mvc.get().uri(PROBES + "/secured").exchange();

    assertProblemResponse(result, ErrorCode.UNAUTHENTICATED);
    assertThat(result.getResponse().getHeader(HttpHeaders.WWW_AUTHENTICATE)).isEqualTo("Bearer");
  }

  @Test
  void securityFiltersAnswerUnauthorisedCallersWith403() {
    MvcTestResult result =
        mvc.get().uri(PROBES + "/admin").with(TestUser.user(1).asRequest()).exchange();

    assertProblemResponse(result, ErrorCode.FORBIDDEN);
  }

  @Test
  void securityExceptionsInsideMvcLookTheSame() {
    MvcTestResult anonymous = mvc.get().uri(PROBES + "/errors/access-denied").exchange();
    MvcTestResult user =
        mvc.get()
            .uri(PROBES + "/errors/access-denied")
            .with(TestUser.user(1).asRequest())
            .exchange();
    MvcTestResult unauthenticated = mvc.get().uri(PROBES + "/errors/authentication").exchange();

    assertThat(assertProblemResponse(anonymous, ErrorCode.UNAUTHENTICATED)).doesNotContain(SECRET);
    assertThat(assertProblemResponse(user, ErrorCode.FORBIDDEN)).doesNotContain(SECRET);
    assertProblemResponse(unauthenticated, ErrorCode.UNAUTHENTICATED);
  }

  // ---- Container error page -------------------------------------------------------------------

  @Test
  void theContainerErrorPageUsesTheSameFormat() {
    MvcTestResult result =
        mvc.get()
            .uri("/error")
            .with(request -> {
              request.setDispatcherType(DispatcherType.ERROR);
              request.setAttribute(RequestDispatcher.ERROR_STATUS_CODE, 400);
              request.setAttribute(RequestDispatcher.ERROR_REQUEST_URI, "/api/v1/rejected");
              return request;
            })
            .exchange();

    JsonNode problem = TestJson.tree(assertProblemResponse(result, ErrorCode.MALFORMED_REQUEST));
    assertThat(problem.path("instance").asString()).isEqualTo("/api/v1/rejected");
  }

  // ---- Helpers ----------------------------------------------------------------------------------

  private MvcTestResult post(String json) {
    return mvc.post().uri(PROBES).contentType(MediaType.APPLICATION_JSON).content(json).exchange();
  }

  /** Status, content type and exact problem structure; returns the body. */
  private static String assertProblemResponse(MvcTestResult result, ErrorCode code) {
    assertThat(result.getResponse().getStatus()).as("status").isEqualTo(code.status());
    assertThat(result.getResponse().getContentType())
        .as("content type")
        .startsWith(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
    String body = body(result);
    assertProblem(body, code);
    return body;
  }

  private static String body(MvcTestResult result) {
    try {
      return result.getResponse().getContentAsString(StandardCharsets.UTF_8);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }
}
