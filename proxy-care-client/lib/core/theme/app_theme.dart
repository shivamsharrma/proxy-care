import 'package:material_ui/material_ui.dart';

import 'app_density.dart';
import 'pc_theme.dart';
import 'tokens/pc_colors.dart';
import 'tokens/pc_shape.dart';
import 'tokens/pc_sizes.dart';
import 'tokens/pc_typography.dart';

/// Builds the Proxy Care `ThemeData` at [density]. No font family is set:
/// Latin text uses the platform's native typeface and Devanagari falls back
/// to the bundled Noto Sans Devanagari.
///
/// The design system defines a light theme only, so there is no dark
/// counterpart (see docs/design-system-mapping.md). Proxy Care components
/// style themselves from [PcTheme]; the `ThemeData` slots below make
/// framework widgets (scaffold, navigation bar, dividers, progress
/// indicators, sheets, snackbars) agree with the same tokens.
ThemeData buildProxyCareTheme([AppDensity density = AppDensity.standard]) {
  final pc = PcTheme.light(density);
  final colors = pc.colors;
  final text = pc.text;

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: proxyCareColorScheme(colors),
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    fontFamilyFallback: PcFonts.fallback,
    textTheme: proxyCareTextTheme(text),
    // Interaction feedback is a flat state layer (8% hover, 12% pressed);
    // the designs have no ink ripple.
    splashFactory: NoSplash.splashFactory,
    // Keep 48px targets and the specified sizes on every platform,
    // including desktop web where Flutter would otherwise compact them.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    dividerTheme: DividerThemeData(
      color: colors.divider,
      thickness: PcBorders.thin,
      space: PcBorders.thin,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.outlineVariant,
      circularTrackColor: colors.secondaryContainer,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      modalBackgroundColor: colors.surface,
      modalBarrierColor: colors.scrim,
      elevation: 0,
      modalElevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PcRadii.xxxl),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.inverseSurface,
      contentTextStyle: PcTypeScale.bodyMd.copyWith(
        color: colors.onInverseSurface,
      ),
      actionTextColor: colors.inversePrimary,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(PcRadii.sm)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: pc.metrics.navBarHeight,
      backgroundColor: colors.surfaceContainer,
      elevation: 0,
      shadowColor: const Color(0x00000000),
      surfaceTintColor: const Color(0x00000000),
      indicatorColor: colors.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.navLabel.copyWith(
          color: states.contains(WidgetState.selected)
              ? colors.text
              : colors.textMuted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: PcSizes.iconLg,
          color: states.contains(WidgetState.selected)
              ? colors.text
              : colors.textMuted,
        ),
      ),
    ),
    extensions: [pc],
  );
}

/// Maps the design system's roles onto Material's [ColorScheme] so
/// framework widgets pick up the brand colors.
///
/// The design system has no separate secondary accent, so `secondary` is
/// the brand primary; its secondary container is `color-secondary-100`.
ColorScheme proxyCareColorScheme(PcColors colors) {
  return ColorScheme(
    brightness: Brightness.light,
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    primaryContainer: colors.primaryContainer,
    onPrimaryContainer: colors.onPrimaryContainer,
    secondary: colors.primary,
    onSecondary: colors.onPrimary,
    secondaryContainer: colors.secondaryContainer,
    onSecondaryContainer: colors.onSecondaryContainer,
    error: colors.errorTone.accent,
    onError: colors.onPrimary,
    errorContainer: colors.errorTone.container,
    onErrorContainer: colors.errorTone.onContainer,
    surface: colors.surface,
    onSurface: colors.text,
    onSurfaceVariant: colors.textMuted,
    surfaceContainerLowest: colors.surface,
    surfaceContainer: colors.surfaceContainer,
    surfaceContainerHigh: colors.surfaceContainerHigh,
    outline: colors.outline,
    outlineVariant: colors.outlineVariant,
    inverseSurface: colors.inverseSurface,
    onInverseSurface: colors.onInverseSurface,
    inversePrimary: colors.inversePrimary,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    // Cards and surfaces are flat and never tinted by elevation.
    surfaceTint: const Color(0x00000000),
  );
}

/// Maps type tokens onto Material's [TextTheme] slots, for framework
/// widgets that read it. Proxy Care components use the tokens directly.
TextTheme proxyCareTextTheme(PcTextStyles text) {
  return TextTheme(
    displaySmall: PcTypeScale.display,
    headlineMedium: PcTypeScale.h1,
    headlineSmall: PcTypeScale.h2,
    titleLarge: PcTypeScale.h3,
    titleMedium: PcTypeScale.titleMd,
    titleSmall: PcTypeScale.titleSm,
    bodyLarge: text.bodyLg,
    bodyMedium: text.bodyMd,
    bodySmall: PcTypeScale.bodySm,
    labelLarge: PcTypeScale.buttonSm,
    labelMedium: text.badge,
    labelSmall: text.navLabel,
  );
}
