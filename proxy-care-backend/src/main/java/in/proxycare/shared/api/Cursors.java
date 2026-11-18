package in.proxycare.shared.api;

import in.proxycare.shared.error.RequestValidationException;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.Objects;

/**
 * Opaque pagination cursors (ADR 0012). A cursor holds the sort key of the last item of a page, as
 * one or more strings (for example a timestamp and an id), so the next page continues after it.
 *
 * <p>Format: URL-safe Base64 without padding of a version marker and the key parts, separated by
 * the ASCII unit separator. Clients must treat it as opaque; anything that does not decode to the
 * expected shape is a 422 on {@code cursor}. Cursors are not signed: tampering can only change
 * where a page starts, never what the caller is allowed to see, because every query applies its own
 * access rules.
 */
public final class Cursors {

  static final String PARAMETER = "cursor";

  /** Bounds work on hostile input; real cursors are far shorter. */
  static final int MAX_LENGTH = 512;

  private static final String VERSION = "1";
  private static final char SEPARATOR = '\u001F';

  private Cursors() {}

  public static String encode(List<String> keyParts) {
    Objects.requireNonNull(keyParts, "keyParts");
    if (keyParts.isEmpty()) {
      throw new IllegalArgumentException("a cursor needs at least one key part");
    }
    StringBuilder payload = new StringBuilder(VERSION);
    for (String part : keyParts) {
      Objects.requireNonNull(part, "key part");
      if (part.indexOf(SEPARATOR) >= 0) {
        throw new IllegalArgumentException("key parts must not contain the separator");
      }
      payload.append(SEPARATOR).append(part);
    }
    String cursor =
        Base64.getUrlEncoder()
            .withoutPadding()
            .encodeToString(payload.toString().getBytes(StandardCharsets.UTF_8));
    if (cursor.length() > MAX_LENGTH) {
      throw new IllegalArgumentException("cursor would exceed " + MAX_LENGTH + " characters");
    }
    return cursor;
  }

  /**
   * The key parts of {@code cursor}, which must have exactly {@code expectedParts} of them.
   *
   * @throws RequestValidationException for any malformed cursor
   */
  public static List<String> decode(String cursor, int expectedParts) {
    if (cursor == null || cursor.isEmpty() || cursor.length() > MAX_LENGTH) {
      throw invalid();
    }
    String payload;
    try {
      payload = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8);
    } catch (IllegalArgumentException notBase64) {
      throw invalid();
    }
    List<String> parts = List.of(payload.split(String.valueOf(SEPARATOR), -1));
    if (parts.size() != expectedParts + 1 || !VERSION.equals(parts.getFirst())) {
      throw invalid();
    }
    return parts.subList(1, parts.size());
  }

  static RequestValidationException invalid() {
    return RequestValidationException.of(PARAMETER, "InvalidCursor", "is not a valid cursor");
  }
}
