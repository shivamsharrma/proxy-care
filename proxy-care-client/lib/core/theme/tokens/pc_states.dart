/// Opacities used for interaction states and imagery, from the component
/// pages (state layers) and section 5 (maps).
abstract final class PcOpacity {
  /// Hover state layer: 8% of the content color.
  static const double hover = 0.08;

  /// Pressed state layer: 12% of the content color.
  static const double pressed = 0.12;

  /// Disabled chips, switches and fields: 38%.
  static const double disabled = 0.38;

  /// Travelled part of a map route: 35%.
  static const double routeTravelled = 0.35;

  /// Caretaker map-marker halo: 18% primary.
  static const double markerHalo = 0.18;
}
