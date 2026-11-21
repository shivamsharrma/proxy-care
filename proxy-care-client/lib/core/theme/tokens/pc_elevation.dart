import 'package:flutter/painting.dart';

/// Shadows from section 4. Cards are flat; shadows exist only on floating
/// overlays, and bottom sheets have none.
abstract final class PcShadows {
  /// `shadow-1` (0 4 12 / 25%): snackbar.
  static const List<BoxShadow> shadow1 = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.25),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  /// `shadow-2` (0 6 16 / 25%): heads-up notification.
  static const List<BoxShadow> shadow2 = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.25),
      offset: Offset(0, 6),
      blurRadius: 16,
    ),
  ];

  /// `shadow-3` (0 8 24 / 20%): dialog.
  static const List<BoxShadow> shadow3 = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.2),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];
}
