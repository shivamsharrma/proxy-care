/// Corner radii from section 4.
abstract final class PcRadii {
  /// `radius-xs` 2: progress.
  static const double xs = 2;

  /// `radius-sm` 4: text fields, snackbar.
  static const double sm = 4;

  /// `radius-md` 8: chips, badges.
  static const double md = 8;

  /// `radius-lg` 12: notes, icon tiles, OTP cells.
  static const double lg = 12;

  /// `radius-xl` 16: cards, lists, selection cards, banners.
  static const double xl = 16;

  /// `radius-2xl` 20: logo tile only.
  static const double xxl = 20;

  /// `radius-3xl` 28: dialogs, sheet tops.
  static const double xxxl = 28;

  /// `radius-full`: buttons, avatars, switches, segmented buttons. Use a
  /// stadium or circle shape; this value is for APIs that need a number.
  static const double full = 9999;
}

/// Border widths from section 4.
abstract final class PcBorders {
  /// `border-thin` 1.
  static const double thin = 1;

  /// `border-thick` 2: focused field, selected card, attention card.
  static const double thick = 2;
}

/// Icon stroke widths from section 5.
abstract final class PcStrokes {
  /// Default outline icon stroke.
  static const double icon = 2;

  /// Check marks (2.5–3; the lower bound is used).
  static const double check = 2.5;

  /// Empty-state illustrations.
  static const double illustration = 1.5;
}
