package in.proxycare.shared.api;

import in.proxycare.shared.error.PreconditionFailedException;
import in.proxycare.shared.error.PreconditionRequiredException;

/**
 * ETags and If-Match for optimistic concurrency (ADR 0012). A resource's ETag is its entity version
 * as a strong tag ({@code "3"}); clients treat it as opaque.
 *
 * <p>Checking If-Match before an update is half of the protection: the update must also go through
 * the entity's {@code @Version}, so a concurrent change committed after the check still fails (and
 * becomes 412 because the request carried If-Match).
 */
public final class EntityTags {

  private EntityTags() {}

  /** The strong ETag for {@code version}. */
  public static String of(long version) {
    return "\"" + version + "\"";
  }

  /**
   * Requires {@code ifMatch} to match {@code currentVersion}.
   *
   * @param ifMatch the If-Match header value, possibly null; {@code *} or a list of tags
   * @throws PreconditionRequiredException when the header is missing or blank (428)
   * @throws PreconditionFailedException when no tag matches (412)
   */
  public static void requireMatch(String ifMatch, long currentVersion) {
    if (ifMatch == null || ifMatch.isBlank()) {
      throw new PreconditionRequiredException();
    }
    String current = of(currentVersion);
    for (String candidate : ifMatch.split(",")) {
      String tag = candidate.trim();
      // If-Match uses strong comparison: a weak tag (W/"3") never matches.
      if (tag.equals("*") || tag.equals(current)) {
        return;
      }
    }
    throw new PreconditionFailedException();
  }
}
