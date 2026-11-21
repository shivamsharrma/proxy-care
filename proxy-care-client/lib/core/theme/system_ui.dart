import 'package:flutter/services.dart';

/// System status and navigation bar styling for the light theme.
///
/// The design system shows screens on `color-bg` with dark text, so the
/// status bar is transparent with dark icons. It does not specify the
/// Android navigation bar, so only its icon brightness is set (dark, to
/// stay legible on the light app surfaces) and its color is left to the
/// platform.
abstract final class PcSystemUi {
  /// Overlay style for every Proxy Care screen.
  static const SystemUiOverlayStyle light = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
}
