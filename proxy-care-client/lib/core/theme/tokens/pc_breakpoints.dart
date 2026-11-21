/// Window size classes for mobile-first adaptive layouts.
enum PcWindowClass {
  /// Below the expanded breakpoint: phones, compact layout.
  compact,

  /// At or above the expanded breakpoint: tablets, adaptive layout.
  expanded,
}

/// Layout breakpoints and content width.
///
/// **Provisional.** The design system defines no breakpoints (it is drawn
/// at a 390px frame). These values are an MVP decision: compact below
/// 600dp, adaptive tablet layout from 600dp, and a maximum width of 720dp
/// for constrained content surfaces (forms, reading columns), applied by
/// choice, never to every component. They live only here, so they can be
/// refined when the design system is updated; a theme can also supply its
/// own instance through `PcTheme.layout`.
final class PcBreakpoints {
  /// Creates breakpoints.
  const PcBreakpoints({
    this.expandedMinWidth = 600,
    this.maxContentWidth = 720,
  });

  /// The provisional MVP values.
  static const PcBreakpoints provisional = PcBreakpoints();

  /// Smallest width, in logical pixels (dp), of the expanded class.
  final double expandedMinWidth;

  /// Maximum width of a constrained content surface.
  final double maxContentWidth;

  /// The window class for a window [width] in logical pixels.
  PcWindowClass classify(double width) => width >= expandedMinWidth
      ? PcWindowClass.expanded
      : PcWindowClass.compact;
}
