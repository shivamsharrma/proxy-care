package in.proxycare.shared.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import in.proxycare.shared.error.RequestValidationException;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import org.junit.jupiter.api.Test;

class CursorsTest {

  @Test
  void roundTripsKeyParts() {
    List<String> key = List.of("2026-01-15T09:00:00Z", "0198f0c2-6a7b-7cc3-9f5e-2b3a4c5d6e7f");

    String cursor = Cursors.encode(key);

    assertThat(Cursors.decode(cursor, 2)).isEqualTo(key);
  }

  @Test
  void isUrlSafeAndOpaque() {
    String cursor = Cursors.encode(List.of("2026-01-15T09:00:00Z", "id/with+chars"));

    assertThat(cursor).matches("[A-Za-z0-9_-]+").doesNotContain("2026");
  }

  @Test
  void keepsEmptyAndNonAsciiParts() {
    List<String> key = List.of("", "जयपुर");

    assertThat(Cursors.decode(Cursors.encode(key), 2)).isEqualTo(key);
  }

  @Test
  void rejectsMalformedCursors() {
    String onePart = Cursors.encode(List.of("a"));
    for (String cursor : List.of("", "***", onePart, "x".repeat(Cursors.MAX_LENGTH + 1))) {
      assertThatThrownBy(() -> Cursors.decode(cursor, 2))
          .as(cursor)
          .isInstanceOf(RequestValidationException.class);
    }
    assertThatThrownBy(() -> Cursors.decode(null, 2))
        .isInstanceOf(RequestValidationException.class);
  }

  @Test
  void rejectsAnotherFormatVersion() {
    String future =
        Base64.getUrlEncoder()
            .withoutPadding()
            .encodeToString("2\u001Fa\u001Fb".getBytes(StandardCharsets.UTF_8));

    assertThatThrownBy(() -> Cursors.decode(future, 2))
        .isInstanceOf(RequestValidationException.class);
  }

  @Test
  void refusesKeysItCannotEncode() {
    assertThatIllegalArgumentException().isThrownBy(() -> Cursors.encode(List.of()));
    assertThatIllegalArgumentException().isThrownBy(() -> Cursors.encode(List.of("a\u001Fb")));
    assertThatIllegalArgumentException().isThrownBy(() -> Cursors.encode(List.of("x".repeat(600))));
  }
}
