package com.proxycare.common.validation;

/**
 * The full-name rule shared by every form that asks for a person's name: English or Hindi letters, spaces and
 * . ' -, with at least one letter. Each request adds its own length limit and trims the name first.
 */
public final class PersonName {

    private static final String LATIN_LETTERS = "A-Za-z";
    private static final String NAME_PUNCTUATION = " .'-";
    private static final String DEVANAGARI_LETTERS = "\\u0904-\\u0939\\u0958-\\u0961\\u0972-\\u097F";
    private static final String DEVANAGARI_MARKS = "\\u0901-\\u0903\\u093C\\u093E-\\u094C\\u094D\\u0962-\\u0963";

    // Devanagari marks are combining characters, so each must follow a Devanagari letter or mark. The rest
    // of the block (danda, digits, avagraha, Om, Vedic accents) stays out. The lookahead needs one letter.
    public static final String FULL_NAME_PATTERN =
            "(?=.*[" + LATIN_LETTERS + DEVANAGARI_LETTERS + "])"
                    + "(?:[" + LATIN_LETTERS + NAME_PUNCTUATION + "]"
                    + "|[" + DEVANAGARI_LETTERS + "][" + DEVANAGARI_MARKS + "]*)*";
    public static final String FULL_NAME_MESSAGE = "may contain only English or Hindi letters, spaces and . ' -";

    private PersonName() {}
}
