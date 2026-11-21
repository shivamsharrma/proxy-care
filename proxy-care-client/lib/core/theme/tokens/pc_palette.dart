import 'package:flutter/painting.dart';

/// Raw color palette of the Proxy Care Design System, section 1 "Color".
///
/// Every value is copied from `claude/proxycare-design-system.md`; the
/// constant names mirror the token names (`color-primary-500` becomes
/// [primary500]). Widgets do not use these directly: they use the semantic
/// roles in `PcColors`, which point at these values.
abstract final class PcPalette {
  // Brand.

  /// `color-primary-50`: selected card / row background.
  static const Color primary50 = Color(0xFFE6F4F1);

  /// `color-primary-100`: secondary text on a primary-500 surface.
  static const Color primary100 = Color(0xFFD7F5EF);

  /// `color-primary-200`: primary container.
  static const Color primary200 = Color(0xFF9EF2E4);

  /// `color-primary-500`: brand primary.
  static const Color primary500 = Color(0xFF006A60);

  /// `color-primary-600`: link / text-action hover.
  static const Color primary600 = Color(0xFF00504A);

  /// `color-primary-900`: text on primary-200.
  static const Color primary900 = Color(0xFF00201C);

  /// `color-secondary-100`: tonal buttons, selected chips, avatars.
  static const Color secondary100 = Color(0xFFCDE8E2);

  /// `color-secondary-900`: text on secondary-100.
  static const Color secondary900 = Color(0xFF051F1C);

  // Semantic hues that are not aliases of other tokens.

  /// `color-warning-100`: warning / pending container.
  static const Color warning100 = Color(0xFFFFDCC4);

  /// `color-warning-500`: warning accent (dots, icons, borders).
  static const Color warning500 = Color(0xFF8B5000);

  /// `color-warning-900`: text on warning-100.
  static const Color warning900 = Color(0xFF2F1500);

  /// `color-error-50`: selected background of the urgent option.
  static const Color error50 = Color(0xFFFFF1EF);

  /// `color-error-100`: error container.
  static const Color error100 = Color(0xFFFFDAD6);

  /// `color-error-500`: error accent and destructive actions.
  static const Color error500 = Color(0xFFBA1A1A);

  /// `color-error-900`: text on error-100.
  static const Color error900 = Color(0xFF410002);

  // Neutrals and surfaces.

  /// `color-neutral-0`: cards, list groups, sheets.
  static const Color neutral0 = Color(0xFFFFFFFF);

  /// `color-neutral-25`: sub-panel inside a card.
  static const Color neutral25 = Color(0xFFF9FCFB);

  /// `color-neutral-50`: app background.
  static const Color neutral50 = Color(0xFFF4FBF8);

  /// `color-neutral-75`: dialog surface.
  static const Color neutral75 = Color(0xFFEEF5F2);

  /// `color-neutral-80`: row dividers.
  static const Color neutral80 = Color(0xFFEEF2F0);

  /// `color-neutral-100`: nav bar, info notes, stat tiles, OTP cells.
  static const Color neutral100 = Color(0xFFE9EFEC);

  /// `color-neutral-110`: map background only.
  static const Color neutral110 = Color(0xFFE6EEE9);

  /// `color-neutral-150`: neutral chips, secondary role card, code box.
  static const Color neutral150 = Color(0xFFE3EAE7);

  /// `color-neutral-200`: card borders, disabled button fill.
  static const Color neutral200 = Color(0xFFDDE4E1);

  /// `color-neutral-220`: map blocks only.
  static const Color neutral220 = Color(0xFFD5E0DA);

  /// `color-neutral-300`: progress track, dashed empty border.
  static const Color neutral300 = Color(0xFFBEC9C6);

  /// `color-neutral-500`: control outlines, disabled text.
  static const Color neutral500 = Color(0xFF6F7977);

  /// `color-neutral-550`: placeholder.
  static const Color neutral550 = Color(0xFF5B6562);

  /// `color-neutral-700`: secondary text.
  static const Color neutral700 = Color(0xFF3F4946);

  /// `color-neutral-800`: inverse surface (snackbar, tooltip).
  static const Color neutral800 = Color(0xFF2B3230);

  /// `color-neutral-850`: text on inverse.
  static const Color neutral850 = Color(0xFFECF2EF);

  /// `color-neutral-900`: primary text.
  static const Color neutral900 = Color(0xFF161D1B);

  /// `color-scrim`: rgba(0,0,0,.32), behind dialogs and modal sheets.
  static const Color scrim = Color.fromRGBO(0, 0, 0, 0.32);
}
