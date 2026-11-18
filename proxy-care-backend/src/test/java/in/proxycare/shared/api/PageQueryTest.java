package in.proxycare.shared.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import in.proxycare.shared.error.FieldValidationError;
import in.proxycare.shared.error.RequestValidationException;
import java.util.List;
import java.util.stream.IntStream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class PageQueryTest {

  @Test
  void defaultsToTheFirstPageOfTwenty() {
    PageQuery page = PageQuery.of(null, null, 2);

    assertThat(page.isFirstPage()).isTrue();
    assertThat(page.size()).isEqualTo(20);
    assertThat(page.fetchSize()).isEqualTo(21);
  }

  @Test
  void continuesAfterTheCursorKey() {
    String cursor = Cursors.encode(List.of("k1", "k2"));

    PageQuery page = PageQuery.of(cursor, 5, 2);

    assertThat(page.after()).containsExactly("k1", "k2");
    assertThat(page.isFirstPage()).isFalse();
  }

  @Test
  void acceptsOneToAHundred() {
    assertThat(PageQuery.of(null, 1, 1).size()).isEqualTo(1);
    assertThat(PageQuery.of(null, 100, 1).size()).isEqualTo(100);
  }

  @ParameterizedTest
  @ValueSource(ints = {0, -5, 101, Integer.MAX_VALUE})
  void refusesSizesOutsideTheRange(int size) {
    assertThatThrownBy(() -> PageQuery.of(null, size, 1))
        .isInstanceOfSatisfying(
            RequestValidationException.class,
            e ->
                assertThat(e.errors())
                    .extracting(FieldValidationError::field)
                    .containsExactly("size"));
  }

  @Test
  void buildsALastPageWhenNothingMoreWasFetched() {
    PageQuery page = PageQuery.of(null, 3, 1);

    PageResponse<Integer> response = page.toResponse(List.of(1, 2, 3), i -> List.of(i.toString()));

    assertThat(response.data()).containsExactly(1, 2, 3);
    assertThat(response.page()).isEqualTo(new PageMetadata(null, false, 3));
  }

  @Test
  void trimsTheExtraItemAndPointsTheCursorAtTheLastReturnedOne() {
    PageQuery page = PageQuery.of(null, 3, 1);

    PageResponse<Integer> response =
        page.toResponse(List.of(1, 2, 3, 4), i -> List.of(i.toString()));

    assertThat(response.data()).containsExactly(1, 2, 3);
    assertThat(response.page().hasMore()).isTrue();
    assertThat(Cursors.decode(response.page().nextCursor(), 1)).containsExactly("3");
  }

  @Test
  void handlesAnEmptyResult() {
    PageResponse<Integer> response =
        PageQuery.of(null, 20, 1).toResponse(List.of(), i -> List.of(i.toString()));

    assertThat(response.data()).isEmpty();
    assertThat(response.page()).isEqualTo(new PageMetadata(null, false, 20));
  }

  @Test
  void neverReturnsMoreThanTheMaximum() {
    List<Integer> fetched = IntStream.rangeClosed(1, 101).boxed().toList();

    PageResponse<Integer> response =
        PageQuery.of(null, 100, 1).toResponse(fetched, i -> List.of(i.toString()));

    assertThat(response.data()).hasSize(100);
  }
}
