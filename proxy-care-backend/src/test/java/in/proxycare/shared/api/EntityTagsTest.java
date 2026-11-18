package in.proxycare.shared.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import in.proxycare.shared.error.PreconditionFailedException;
import in.proxycare.shared.error.PreconditionRequiredException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

class EntityTagsTest {

  @Test
  void isAStrongTagOfTheVersion() {
    assertThat(EntityTags.of(0)).isEqualTo("\"0\"");
    assertThat(EntityTags.of(42)).isEqualTo("\"42\"");
  }

  @ParameterizedTest
  @ValueSource(strings = {"\"3\"", "*", " \"3\" ", "\"1\", \"3\"", "\"1\",\"3\""})
  void matchesTheCurrentVersion(String ifMatch) {
    assertThatCode(() -> EntityTags.requireMatch(ifMatch, 3)).doesNotThrowAnyException();
  }

  @ParameterizedTest
  @ValueSource(strings = {"\"2\"", "W/\"3\"", "3", "\"3", "\"\"", "\"1\", \"2\""})
  void refusesEverythingElseWith412(String ifMatch) {
    assertThatThrownBy(() -> EntityTags.requireMatch(ifMatch, 3))
        .isInstanceOf(PreconditionFailedException.class);
  }

  @ParameterizedTest
  @NullAndEmptySource
  @ValueSource(strings = {"  "})
  void requiresTheHeaderWith428(String ifMatch) {
    assertThatThrownBy(() -> EntityTags.requireMatch(ifMatch, 3))
        .isInstanceOf(PreconditionRequiredException.class);
  }
}
