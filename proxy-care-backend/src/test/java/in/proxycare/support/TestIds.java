package in.proxycare.support;

import java.util.UUID;

/**
 * Readable, deterministic UUIDs for test data. {@code TestIds.account(7)} is always {@code
 * 00000001-0000-4000-8000-000000000007}, so failures name the same ids on every run.
 */
public final class TestIds {

  private static final long MAX_NUMBER = 0xFFFF_FFFF_FFFFL;

  private TestIds() {}

  /** A backend account id. */
  public static UUID account(long number) {
    return uuid(1, number);
  }

  /** A Supabase user id (a token's {@code sub}). */
  public static UUID authUser(long number) {
    return uuid(2, number);
  }

  /** Any other entity; {@code group} keeps kinds of entities apart. */
  public static UUID uuid(int group, long number) {
    if (group < 0 || number < 0 || number > MAX_NUMBER) {
      throw new IllegalArgumentException("group and number must be small non-negative values");
    }
    return UUID.fromString(String.format("%08x-0000-4000-8000-%012x", group, number));
  }
}
