import 'package:flutter/foundation.dart';

/// The platform the app runs on: the only device information the app
/// collects (it is needed to register push tokens). See SECURITY.md,
/// "Device information".
enum AppPlatform {
  /// A browser.
  web,

  /// Android.
  android,

  /// iOS.
  ios,

  /// Anything else (desktop; not a supported target).
  other;

  /// The platform of this build.
  static AppPlatform get current {
    if (kIsWeb) return AppPlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AppPlatform.android,
      TargetPlatform.iOS => AppPlatform.ios,
      _ => AppPlatform.other,
    };
  }
}
