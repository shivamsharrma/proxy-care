import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app_density.dart';
import 'app_theme.dart';

/// The density the app renders at.
///
/// Defaults to [AppDensity.standard] (family app). Which audience a session
/// belongs to is decided by a later feature, which calls
/// `AppDensityController.select`.
final appDensityProvider = NotifierProvider<AppDensityController, AppDensity>(
  AppDensityController.new,
);

/// Holds and changes the current [AppDensity].
class AppDensityController extends Notifier<AppDensity> {
  @override
  AppDensity build() => AppDensity.standard;

  /// Switches the app to [density].
  void select(AppDensity density) => state = density;
}

/// The app's `ThemeData`, rebuilt when the density changes.
final appThemeProvider = Provider<ThemeData>(
  (ref) => buildProxyCareTheme(ref.watch(appDensityProvider)),
);

/// The theme mode. The design system defines a light theme only, so this is
/// always [ThemeMode.light]; it is a provider so a dark theme can be added
/// without changing the app widget.
final appThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.light);
