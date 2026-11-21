import 'package:flutter/painting.dart';

/// Font families. The design system names Roboto with Noto Sans
/// Devanagari for Hindi; the MVP decision is to use the platform's native
/// typeface for Latin text (no font family is set, so Android, iOS and the
/// web engine use their default) and to bundle only Noto Sans Devanagari,
/// which every style lists as its fallback.
abstract final class PcFonts {
  /// The bundled Devanagari family (weights 400, 500, 700; see pubspec).
  static const String devanagari = 'Noto Sans Devanagari';

  /// Fallback stack after the platform's default family.
  static const List<String> fallback = [devanagari];
}

/// Every type token in the design system, with the exact size, line height,
/// weight and tracking given in section 2. Colors are not part of a type
/// token; components apply them.
///
/// Names mirror the tokens: `title-md` is [titleMd], `c-body-lg` (the
/// comfortable-density step-up) is [cBodyLg].
abstract final class PcTypeScale {
  // Standard density.

  /// `display` 36 / 44, 500, -0.25.
  static const TextStyle display = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 36,
    height: 44 / 36,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.25,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `h1` 28 / 36, 400.
  static const TextStyle h1 = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `h2` 24 / 32, 400.
  static const TextStyle h2 = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `h3` 22 / 28, 400.
  static const TextStyle h3 = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `title-md` 18 / 24, 500.
  static const TextStyle titleMd = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `title-sm` 16 / 24, 500.
  static const TextStyle titleSm = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `body-lg` 16 / 24, 400.
  static const TextStyle bodyLg = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `body-md` 14 / 20, 400.
  static const TextStyle bodyMd = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `body-sm` (caption) 12 / 16, 400, 0.4.
  static const TextStyle bodySm = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `list-title` 15 / 20, 500.
  static const TextStyle listTitle = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `list-meta` 13 / 18, 400.
  static const TextStyle listMeta = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `button` 16 / 24, 500, 0.1.
  static const TextStyle button = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `button-sm` 14 / 20, 500, 0.1.
  static const TextStyle buttonSm = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `section-label` 14 / 20, 500, 0.1.
  static const TextStyle sectionLabel = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `field-label` 12 / 16, 400.
  static const TextStyle fieldLabel = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `overline` 12 / 16, 500, 0.5. Used uppercase.
  static const TextStyle overline = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `badge` 13 / 16, 500.
  static const TextStyle badge = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `nav-label` 12 / 16, 500 (700 when active).
  static const TextStyle navLabel = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `micro` 11 / 14, 400. Visit-progress labels only.
  static const TextStyle micro = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `amount-xl` 32 / 40, 500.
  static const TextStyle amountXl = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `amount-lg` 26 / 32, 500.
  static const TextStyle amountLg = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `amount-md` 22 / 28, 500.
  static const TextStyle amountMd = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `otp-digit` 24 / 32, 500.
  static const TextStyle otpDigit = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `code` 22 / 28, 500, 4.
  static const TextStyle code = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 4,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Comfortable density (caretaker app) step-ups.

  /// `c-body-lg` 18 / 26, 400.
  static const TextStyle cBodyLg = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `c-body-option` 17 / 24, 400.
  static const TextStyle cBodyOption = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `c-body-md` 15 / 22, 400.
  static const TextStyle cBodyMd = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `c-section-label` 16 / 24, 500.
  static const TextStyle cSectionLabel = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `c-button` 18 / 24, 500, 0.1.
  static const TextStyle cButton = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `c-field-label` 13 / 16, 400.
  static const TextStyle cFieldLabel = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Comfortable helper text, 13 / 18, 400 ("helper 13/18").
  static const TextStyle cHelper = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// `c-nav-label` 13 / 16, 500.
  static const TextStyle cNavLabel = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Comfortable status badge label: 15px, 500 (Badge page). The page gives
  /// no line height, so this keeps the `badge` token's 16px.
  static const TextStyle cBadge = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 15,
    height: 16 / 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Modal progress sheet title, 20 / 28, 500 (BottomSheet page). Not part
  /// of the named scale; see docs/design-system-mapping.md.
  static const TextStyle sheetTitle = TextStyle(
    fontFamilyFallback: PcFonts.fallback,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// Text roles whose token depends on density (section 2, "Comfortable
/// density"). Headings, titles and amounts are the same in both densities
/// and are read from [PcTypeScale] directly.
final class PcTextStyles {
  /// Creates a role set.
  const PcTextStyles({
    required this.bodyLg,
    required this.bodyMd,
    required this.optionLabel,
    required this.sectionLabel,
    required this.fieldLabel,
    required this.helper,
    required this.navLabel,
    required this.badge,
    required this.stepCaption,
    required this.emptyState,
  });

  /// Family app.
  static const PcTextStyles standard = PcTextStyles(
    bodyLg: PcTypeScale.bodyLg,
    bodyMd: PcTypeScale.bodyMd,
    optionLabel: PcTypeScale.bodyLg,
    sectionLabel: PcTypeScale.sectionLabel,
    fieldLabel: PcTypeScale.fieldLabel,
    helper: PcTypeScale.bodySm,
    navLabel: PcTypeScale.navLabel,
    badge: PcTypeScale.badge,
    stepCaption: PcTypeScale.bodySm,
    emptyState: PcTypeScale.bodyMd,
  );

  /// Caretaker app.
  static const PcTextStyles comfortable = PcTextStyles(
    bodyLg: PcTypeScale.cBodyLg,
    bodyMd: PcTypeScale.cBodyMd,
    optionLabel: PcTypeScale.cBodyOption,
    sectionLabel: PcTypeScale.cSectionLabel,
    fieldLabel: PcTypeScale.cFieldLabel,
    helper: PcTypeScale.cHelper,
    navLabel: PcTypeScale.cNavLabel,
    badge: PcTypeScale.cBadge,
    // Decision #7: caretaker step caption is 14/20.
    stepCaption: PcTypeScale.bodyMd,
    // EmptyState page: 16/24 in caretaker.
    emptyState: PcTypeScale.bodyLg,
  );

  /// Intro paragraphs and input text (`body-lg` / `c-body-lg`).
  final TextStyle bodyLg;

  /// Supporting text (`body-md` / `c-body-md`).
  final TextStyle bodyMd;

  /// Radio and checklist option labels (`body-lg` / `c-body-option`).
  final TextStyle optionLabel;

  /// Section headers (`section-label` / `c-section-label`).
  final TextStyle sectionLabel;

  /// Floating field labels (`field-label` / `c-field-label`).
  final TextStyle fieldLabel;

  /// Helper text under fields (`body-sm` / 13/18).
  final TextStyle helper;

  /// Bottom navigation labels (`nav-label` / `c-nav-label`).
  final TextStyle navLabel;

  /// Status badge labels (13 / 15).
  final TextStyle badge;

  /// "Step n of N" caption (12/16 +0.4 / 14/20).
  final TextStyle stepCaption;

  /// Empty-state sentence (`body-md` / 16/24).
  final TextStyle emptyState;
}
