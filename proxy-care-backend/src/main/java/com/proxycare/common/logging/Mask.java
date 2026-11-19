package com.proxycare.common.logging;

/** Masks sensitive values for logs. Every method returns null for null. */
public final class Mask {

    private static final String HIDDEN = "****";

    private Mask() {}

    /** {@code +919876543210} becomes {@code +91******3210}; anything too short to mask safely becomes {@code ****}. */
    public static String phone(String phone) {
        if (phone == null) {
            return null;
        }
        if (phone.length() < 8) {
            return HIDDEN;
        }
        return phone.substring(0, 3) + "*".repeat(phone.length() - 7) + phone.substring(phone.length() - 4);
    }

    /** OTP codes, tokens and anything else that must never appear. */
    public static String fully(String value) {
        return value == null ? null : HIDDEN;
    }

    /** {@code 123456781234} becomes {@code ****1234}; four characters or fewer become {@code ****}. */
    public static String last4(String value) {
        if (value == null) {
            return null;
        }
        return value.length() <= 4 ? HIDDEN : HIDDEN + value.substring(value.length() - 4);
    }
}
