import 'package:flutter/painting.dart';

import 'pc_palette.dart';

/// Status tones from the design system's "Semantic" color table and the
/// status usage rule: pending / in progress = [warning], done / paid =
/// [success], failed / blocked = [error], neutral info = [info].
///
/// [neutral] is the fourth status-badge tone ("Neutral `color-neutral-150` /
/// `color-text` / `color-outline`").
enum PcTone { neutral, info, warning, success, error }

/// The three colors a tone is used with (the design system's "tint rule"):
/// a light [container], a dark [onContainer] for text and icons on it, and a
/// mid [accent] used only for dots, icons and borders.
final class PcToneColors {
  /// Creates a tone triple.
  const PcToneColors({
    required this.container,
    required this.accent,
    required this.onContainer,
  });

  /// Background of badges, banners and icon wells in this tone.
  final Color container;

  /// Dots, icons and borders. Never body text on white, except the primary
  /// and error accents.
  final Color accent;

  /// Text and icons on [container].
  final Color onContainer;
}

/// Semantic color roles. Components use these, never [PcPalette] directly,
/// so a future theme only has to provide another instance.
///
/// The design system defines a light theme only; [light] is that theme.
final class PcColors {
  /// Creates a full set of color roles.
  const PcColors({
    required this.primary,
    required this.primaryHover,
    required this.onPrimary,
    required this.onPrimaryMuted,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primarySelected,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.bg,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.dialogSurface,
    required this.text,
    required this.textMuted,
    required this.placeholder,
    required this.border,
    required this.divider,
    required this.outline,
    required this.outlineVariant,
    required this.disabledBg,
    required this.disabledText,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.errorSelected,
    required this.mapGround,
    required this.mapBlock,
    required this.scrim,
    required this.neutralTone,
    required this.infoTone,
    required this.warningTone,
    required this.successTone,
    required this.errorTone,
  });

  /// The design system's light theme (the only theme it defines).
  static const PcColors light = PcColors(
    primary: PcPalette.primary500,
    primaryHover: PcPalette.primary600,
    onPrimary: PcPalette.neutral0,
    onPrimaryMuted: PcPalette.primary100,
    primaryContainer: PcPalette.primary200,
    onPrimaryContainer: PcPalette.primary900,
    primarySelected: PcPalette.primary50,
    secondaryContainer: PcPalette.secondary100,
    onSecondaryContainer: PcPalette.secondary900,
    bg: PcPalette.neutral50,
    surface: PcPalette.neutral0,
    surfaceSubtle: PcPalette.neutral25,
    surfaceContainer: PcPalette.neutral100,
    surfaceContainerHigh: PcPalette.neutral150,
    dialogSurface: PcPalette.neutral75,
    text: PcPalette.neutral900,
    textMuted: PcPalette.neutral700,
    placeholder: PcPalette.neutral550,
    border: PcPalette.neutral200,
    divider: PcPalette.neutral80,
    outline: PcPalette.neutral500,
    outlineVariant: PcPalette.neutral300,
    disabledBg: PcPalette.neutral200,
    disabledText: PcPalette.neutral500,
    inverseSurface: PcPalette.neutral800,
    onInverseSurface: PcPalette.neutral850,
    inversePrimary: PcPalette.primary200,
    errorSelected: PcPalette.error50,
    mapGround: PcPalette.neutral110,
    mapBlock: PcPalette.neutral220,
    scrim: PcPalette.scrim,
    neutralTone: PcToneColors(
      container: PcPalette.neutral150,
      accent: PcPalette.neutral500,
      onContainer: PcPalette.neutral900,
    ),
    infoTone: PcToneColors(
      container: PcPalette.neutral100,
      // Info has no accent ("—" in the spec); icons use the on-color.
      accent: PcPalette.neutral700,
      onContainer: PcPalette.neutral700,
    ),
    warningTone: PcToneColors(
      container: PcPalette.warning100,
      accent: PcPalette.warning500,
      onContainer: PcPalette.warning900,
    ),
    successTone: PcToneColors(
      container: PcPalette.primary200,
      accent: PcPalette.primary500,
      onContainer: PcPalette.primary900,
    ),
    errorTone: PcToneColors(
      container: PcPalette.error100,
      accent: PcPalette.error500,
      onContainer: PcPalette.error900,
    ),
  );

  /// `color-primary-500`.
  final Color primary;

  /// `color-primary-600`: link / text-action hover.
  final Color primaryHover;

  /// `color-neutral-0`: label on filled primary and destructive buttons.
  final Color onPrimary;

  /// `color-primary-100`: secondary text on a primary surface.
  final Color onPrimaryMuted;

  /// `color-primary-200`.
  final Color primaryContainer;

  /// `color-primary-900`.
  final Color onPrimaryContainer;

  /// `color-primary-50`: selected card / row background.
  final Color primarySelected;

  /// `color-secondary-100`.
  final Color secondaryContainer;

  /// `color-secondary-900`.
  final Color onSecondaryContainer;

  /// `color-bg` (`color-neutral-50`): app background.
  final Color bg;

  /// `color-surface` (`color-neutral-0`): cards, list groups, sheets.
  final Color surface;

  /// `color-neutral-25`: sub-panel inside a card.
  final Color surfaceSubtle;

  /// `color-surface-container` (`color-neutral-100`).
  final Color surfaceContainer;

  /// `color-surface-container-high` (`color-neutral-150`).
  final Color surfaceContainerHigh;

  /// `color-neutral-75`: dialog surface.
  final Color dialogSurface;

  /// `color-text` (`color-neutral-900`).
  final Color text;

  /// `color-text-muted` (`color-neutral-700`).
  final Color textMuted;

  /// `color-neutral-550`: placeholder.
  final Color placeholder;

  /// `color-border` (`color-neutral-200`): decorative card outline.
  final Color border;

  /// `color-divider` (`color-neutral-80`).
  final Color divider;

  /// `color-outline` (`color-neutral-500`): control borders (3:1).
  final Color outline;

  /// `color-neutral-300`: progress track, dashed borders, OTP cell border.
  final Color outlineVariant;

  /// `color-disabled-bg` (`color-neutral-200`).
  final Color disabledBg;

  /// `color-disabled-text` (`color-neutral-500`).
  final Color disabledText;

  /// `color-neutral-800`: snackbar, heads-up, tooltip.
  final Color inverseSurface;

  /// `color-neutral-850`: text on the inverse surface.
  final Color onInverseSurface;

  /// `color-primary-200` used as action text on the inverse surface.
  final Color inversePrimary;

  /// `color-error-50`: selected urgent option.
  final Color errorSelected;

  /// `color-neutral-110`: map ground.
  final Color mapGround;

  /// `color-neutral-220`: map blocks.
  final Color mapBlock;

  /// `color-scrim`.
  final Color scrim;

  /// Neutral status tone.
  final PcToneColors neutralTone;

  /// `color-info-*`.
  final PcToneColors infoTone;

  /// `color-warning-*` (pending / in progress).
  final PcToneColors warningTone;

  /// `color-success-*` (done / paid). Shares the brand hue by design.
  final PcToneColors successTone;

  /// `color-error-*` (failed / blocked).
  final PcToneColors errorTone;

  /// The colors for [tone].
  PcToneColors tone(PcTone tone) => switch (tone) {
    PcTone.neutral => neutralTone,
    PcTone.info => infoTone,
    PcTone.warning => warningTone,
    PcTone.success => successTone,
    PcTone.error => errorTone,
  };
}
