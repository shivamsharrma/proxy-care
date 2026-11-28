package com.proxycare.common.validation;

/** The IFSC format: 4 bank letters, a zero, then 6 letters or digits, upper case (the app upper-cases input). */
public final class Ifsc {

    public static final String IFSC_PATTERN = "^[A-Z]{4}0[A-Z0-9]{6}$";
    public static final String IFSC_MESSAGE = "must be an 11-character IFSC in upper case";

    private Ifsc() {}
}
