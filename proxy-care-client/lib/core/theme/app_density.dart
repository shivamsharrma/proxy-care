import 'tokens/pc_sizes.dart';
import 'tokens/pc_typography.dart';

/// The design system's two densities: one system, two audiences.
///
/// Both share every color, radius and component; only sizes change.
enum AppDensity {
  /// Family app: standard density.
  standard,

  /// Caretaker app: type +1–2px, primary buttons 64px, inputs 60px.
  comfortable,
}

/// Sizes that differ between densities.
final class PcDensityMetrics {
  /// Creates a metric set.
  const PcDensityMetrics({
    required this.screenActionHeight,
    required this.inputHeight,
    required this.navBarHeight,
    required this.badgeHeight,
  });

  /// Family app.
  static const PcDensityMetrics standard = PcDensityMetrics(
    screenActionHeight: PcSizes.buttonLg,
    inputHeight: PcSizes.buttonLg,
    navBarHeight: PcSizes.navBar,
    badgeHeight: PcSizes.badge,
  );

  /// Caretaker app.
  static const PcDensityMetrics comfortable = PcDensityMetrics(
    screenActionHeight: PcSizes.buttonXl,
    inputHeight: PcSizes.inputComfortable,
    navBarHeight: PcSizes.navBarComfortable,
    badgeHeight: PcSizes.badgeComfortable,
  );

  /// Height of the full-width primary action (56 / 64).
  final double screenActionHeight;

  /// Text field height (56 / 60).
  final double inputHeight;

  /// Bottom navigation height (80 / 84).
  final double navBarHeight;

  /// Status badge height (28 / 32).
  final double badgeHeight;
}

/// Density lookups.
extension AppDensityTokens on AppDensity {
  /// Sizes for this density.
  PcDensityMetrics get metrics => switch (this) {
    AppDensity.standard => PcDensityMetrics.standard,
    AppDensity.comfortable => PcDensityMetrics.comfortable,
  };

  /// Text roles for this density.
  PcTextStyles get textStyles => switch (this) {
    AppDensity.standard => PcTextStyles.standard,
    AppDensity.comfortable => PcTextStyles.comfortable,
  };
}
