import 'package:material_ui/material_ui.dart';

import 'app_density.dart';
import 'tokens/pc_breakpoints.dart';
import 'tokens/pc_colors.dart';
import 'tokens/pc_typography.dart';

/// Design-system values that `ThemeData` has no slot for: the semantic
/// color roles, the density-dependent text roles and sizes.
///
/// Registered on `ThemeData.extensions` by `buildProxyCareTheme`; widgets
/// read it with `context.pc`.
@immutable
final class PcTheme extends ThemeExtension<PcTheme> {
  /// Creates a theme extension.
  const PcTheme({
    required this.density,
    required this.colors,
    required this.text,
    required this.metrics,
    this.layout = PcBreakpoints.provisional,
  });

  /// The light theme at [density].
  factory PcTheme.light(AppDensity density) => PcTheme(
    density: density,
    colors: PcColors.light,
    text: density.textStyles,
    metrics: density.metrics,
  );

  /// Standard (family) or comfortable (caretaker) density.
  final AppDensity density;

  /// Semantic color roles.
  final PcColors colors;

  /// Density-dependent text roles.
  final PcTextStyles text;

  /// Density-dependent sizes.
  final PcDensityMetrics metrics;

  /// Breakpoints and maximum content width (provisional).
  final PcBreakpoints layout;

  /// Whether this is the caretaker density.
  bool get isComfortable => density == AppDensity.comfortable;

  @override
  PcTheme copyWith({
    AppDensity? density,
    PcColors? colors,
    PcTextStyles? text,
    PcDensityMetrics? metrics,
    PcBreakpoints? layout,
  }) {
    return PcTheme(
      density: density ?? this.density,
      colors: colors ?? this.colors,
      text: text ?? this.text,
      metrics: metrics ?? this.metrics,
      layout: layout ?? this.layout,
    );
  }

  /// Tokens are discrete, so a theme animation switches at the midpoint.
  @override
  PcTheme lerp(covariant PcTheme? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

/// Access to [PcTheme] from widgets.
extension PcThemeContext on BuildContext {
  /// The [PcTheme] of the nearest `Theme`, or the standard light theme when
  /// the app theme was not built with `buildProxyCareTheme`.
  PcTheme get pc =>
      Theme.of(this).extension<PcTheme>() ?? PcTheme.light(AppDensity.standard);

  /// The window size class of the current window.
  PcWindowClass get pcWindowClass =>
      pc.layout.classify(MediaQuery.sizeOf(this).width);
}
