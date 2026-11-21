import 'package:flutter/widgets.dart' show AppLifecycleState;

/// The app's lifecycle, as services need it.
///
/// Followed by `appLifecyclePhaseProvider`: services react with
/// `ref.listen(appLifecyclePhaseProvider, ...)` instead of observing
/// widgets.
enum AppLifecyclePhase {
  /// Visible and receiving input.
  foreground,

  /// Visible but not receiving input (a system dialog, the app switcher,
  /// an incoming call). Short-lived.
  inactive,

  /// Not visible (Flutter's `hidden` and `paused`). The process may be
  /// killed without further notice: save what must survive now.
  background,

  /// The engine runs without a view (app closing, or not yet shown).
  detached,
}

/// The phase for Flutter's [state].
AppLifecyclePhase phaseOf(AppLifecycleState state) => switch (state) {
  AppLifecycleState.resumed => AppLifecyclePhase.foreground,
  AppLifecycleState.inactive => AppLifecyclePhase.inactive,
  AppLifecycleState.hidden ||
  AppLifecycleState.paused => AppLifecyclePhase.background,
  AppLifecycleState.detached => AppLifecyclePhase.detached,
};
