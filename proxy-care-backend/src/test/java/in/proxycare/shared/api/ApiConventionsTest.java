package in.proxycare.shared.api;

import static in.proxycare.support.ApiAssertions.assertData;
import static in.proxycare.support.ApiAssertions.assertPage;
import static in.proxycare.support.ApiAssertions.assertProblem;
import static in.proxycare.support.ApiAssertions.errors;
import static org.assertj.core.api.Assertions.assertThat;

import in.proxycare.shared.error.ErrorCode;
import in.proxycare.shared.error.FieldValidationError;
import in.proxycare.support.Concurrently;
import in.proxycare.support.Concurrently.Outcome;
import in.proxycare.support.IntegrationTest;
import in.proxycare.support.TestJson;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;
import tools.jackson.databind.JsonNode;

/**
 * Success responses, pagination and optimistic concurrency through the real stack (ADR 0012), using
 * the test-only probe API under {@code /api/v1/probes}.
 */
@IntegrationTest
class ApiConventionsTest {

  private static final String PROBES = "/api/v1/probes";

  @Autowired private MockMvcTester mvc;

  // ---- Base path and success shapes -----------------------------------------------------------

  @Test
  void servesApplicationControllersUnderTheVersionedBasePath() {
    MvcTestResult unprefixed = mvc.get().uri("/probes").exchange();

    // Without the prefix the path is not the probe API, so the deny-all chain answers.
    assertThat(unprefixed.getResponse().getStatus()).isEqualTo(401);
    assertThat(mvc.get().uri(PROBES).exchange().getResponse().getStatus()).isEqualTo(200);
  }

  @Test
  void createsWithLocationEtagAndDataBody() {
    MvcTestResult result = create("first", 109_900);

    assertThat(result.getResponse().getStatus()).isEqualTo(201);
    JsonNode data = assertData(body(result));
    String id = data.path("id").asString();
    assertThat(result.getResponse().getHeader(HttpHeaders.LOCATION)).isEqualTo(PROBES + "/" + id);
    assertThat(result.getResponse().getHeader(HttpHeaders.ETAG)).isEqualTo("\"0\"");
    assertThat(data.path("amountPaise").asLong()).isEqualTo(109_900);
    assertThat(data.path("createdAt").asString()).isEqualTo("2026-01-15T09:00:00Z");
  }

  @Test
  void readsOneResourceWithItsEtag() {
    String id = idOf(create("one", 1));

    MvcTestResult result = mvc.get().uri(PROBES + "/" + id).exchange();

    assertThat(result.getResponse().getStatus()).isEqualTo(200);
    assertThat(result.getResponse().getHeader(HttpHeaders.ETAG)).isEqualTo("\"0\"");
    assertThat(assertData(body(result)).path("name").asString()).isEqualTo("one");
  }

  // ---- If-Match ---------------------------------------------------------------------------------

  @Test
  void updatesWhenIfMatchIsCurrentAndReturnsTheNewEtag() {
    String id = idOf(create("before", 1));

    MvcTestResult result = rename(id, "\"0\"", "after");

    assertThat(result.getResponse().getStatus()).isEqualTo(200);
    assertThat(result.getResponse().getHeader(HttpHeaders.ETAG)).isEqualTo("\"1\"");
    assertThat(assertData(body(result)).path("name").asString()).isEqualTo("after");
  }

  @ParameterizedTest
  @ValueSource(strings = {"*", "\"7\", \"0\""})
  void acceptsAWildcardOrAListContainingTheCurrentTag(String ifMatch) {
    String id = idOf(create("x", 1));

    assertThat(rename(id, ifMatch, "y").getResponse().getStatus()).isEqualTo(200);
  }

  @ParameterizedTest
  @ValueSource(strings = {"\"5\"", "W/\"0\"", "0"})
  void refusesAStaleWeakOrUnquotedTagWith412(String ifMatch) {
    String id = idOf(create("x", 1));

    assertProblem(body(rename(id, ifMatch, "y")), ErrorCode.PRECONDITION_FAILED);
    assertThat(
            mvc.get().uri(PROBES + "/" + id).exchange().getResponse().getHeader(HttpHeaders.ETAG))
        .isEqualTo("\"0\"");
  }

  @Test
  void requiresIfMatchWith428() {
    String id = idOf(create("x", 1));

    MvcTestResult result =
        mvc.patch()
            .uri(PROBES + "/" + id)
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"name\": \"y\"}")
            .exchange();

    assertThat(result.getResponse().getStatus()).isEqualTo(428);
    assertProblem(body(result), ErrorCode.PRECONDITION_REQUIRED);
  }

  @Test
  void letsExactlyOneOfManyConcurrentUpdatesWin() {
    String id = idOf(create("contested", 1));

    List<Outcome<Integer>> outcomes =
        Concurrently.run(8, () -> rename(id, "\"0\"", "winner").getResponse().getStatus());

    assertThat(outcomes).allMatch(Outcome::succeeded);
    assertThat(outcomes).extracting(Outcome::value).containsOnlyOnce(200);
    assertThat(outcomes).extracting(Outcome::value).filteredOn(status -> status == 412).hasSize(7);
    assertThat(
            mvc.get().uri(PROBES + "/" + id).exchange().getResponse().getHeader(HttpHeaders.ETAG))
        .isEqualTo("\"1\"");
  }

  // ---- Pagination -------------------------------------------------------------------------------

  @Test
  void pagesThroughACollectionWithOpaqueCursors() {
    List<String> created = new ArrayList<>();
    for (int i = 1; i <= 5; i++) {
      created.add(idOf(create("p" + i, i)));
    }

    List<String> seen = new ArrayList<>();
    String cursor = null;
    List<Boolean> hasMore = new ArrayList<>();
    do {
      String uri = PROBES + "?size=2" + (cursor == null ? "" : "&cursor=" + cursor);
      JsonNode page = assertPage(body(mvc.get().uri(uri).exchange()));
      page.path("data").forEach(item -> seen.add(item.path("id").asString()));
      assertThat(page.path("page").path("size").asInt()).isEqualTo(2);
      hasMore.add(page.path("page").path("hasMore").asBoolean());
      cursor =
          page.path("page").path("nextCursor").isNull()
              ? null
              : page.path("page").path("nextCursor").asString();
    } while (cursor != null);

    assertThat(seen).containsExactlyInAnyOrderElementsOf(created).doesNotHaveDuplicates();
    assertThat(hasMore).containsExactly(true, true, false);
  }

  @Test
  void returnsAnEmptyLastPage() {
    JsonNode page = assertPage(body(mvc.get().uri(PROBES).exchange()));

    assertThat(page.path("data").isEmpty()).isTrue();
    assertThat(page.path("page").path("hasMore").asBoolean()).isFalse();
    assertThat(page.path("page").path("nextCursor").isNull()).isTrue();
  }

  @Test
  void usesTwentyItemsByDefault() {
    JsonNode page = assertPage(body(mvc.get().uri(PROBES).exchange()));

    assertThat(page.path("page").path("size").asInt()).isEqualTo(PageQuery.DEFAULT_SIZE);
  }

  @Test
  void endsExactlyWhenTheLastPageIsFull() {
    create("a", 1);
    create("b", 2);

    JsonNode page = assertPage(body(mvc.get().uri(PROBES + "?size=2").exchange()));

    assertThat(page.path("data").size()).isEqualTo(2);
    assertThat(page.path("page").path("hasMore").asBoolean()).isFalse();
  }

  @ParameterizedTest
  @ValueSource(ints = {1, 100})
  void acceptsTheSizeBounds(int size) {
    assertThat(mvc.get().uri(PROBES + "?size=" + size).exchange().getResponse().getStatus())
        .isEqualTo(200);
  }

  @ParameterizedTest
  @ValueSource(ints = {0, -1, 101})
  void refusesSizesOutsideOneToAHundred(int size) {
    JsonNode problem =
        assertProblem(
            body(mvc.get().uri(PROBES + "?size=" + size).exchange()), ErrorCode.VALIDATION_ERROR);

    assertThat(errors(problem)).extracting(FieldValidationError::field).containsExactly("size");
  }

  @Test
  void refusesMalformedOrTamperedCursors() {
    String wrongShape =
        Base64.getUrlEncoder()
            .withoutPadding()
            .encodeToString("2\u001Fonly-one".getBytes(StandardCharsets.UTF_8));
    for (String cursor : List.of("not*base64", wrongShape, "x".repeat(600))) {
      JsonNode problem =
          assertProblem(
              body(mvc.get().uri(PROBES + "?cursor=" + cursor).exchange()),
              ErrorCode.VALIDATION_ERROR);

      assertThat(errors(problem))
          .as("cursor %s", cursor)
          .containsExactly(
              new FieldValidationError("cursor", "InvalidCursor", "is not a valid cursor"));
    }
  }

  // ---- Helpers ----------------------------------------------------------------------------------

  private MvcTestResult create(String name, long amountPaise) {
    return mvc.post()
        .uri(PROBES)
        .contentType(MediaType.APPLICATION_JSON)
        .content(
            TestJson.write(
                new java.util.LinkedHashMap<>(
                    java.util.Map.of("name", name, "amountPaise", amountPaise))))
        .exchange();
  }

  private MvcTestResult rename(String id, String ifMatch, String name) {
    return mvc.patch()
        .uri(PROBES + "/" + id)
        .header(HttpHeaders.IF_MATCH, ifMatch)
        .contentType(MediaType.APPLICATION_JSON)
        .content("{\"name\": \"" + name + "\"}")
        .exchange();
  }

  private static String idOf(MvcTestResult created) {
    return TestJson.tree(body(created)).path("data").path("id").asString();
  }

  private static String body(MvcTestResult result) {
    try {
      return result.getResponse().getContentAsString(StandardCharsets.UTF_8);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }
}
