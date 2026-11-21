import 'package:proxy_care_client/core/config/env.dart';

/// A valid development [Env] for tests. Override only what a test cares
/// about.
Env testEnv({
  String appEnv = 'development',
  String apiBaseUrl = 'http://localhost:8080',
  String appName = 'Proxy Care Test',
  bool enableLogging = false,
  String featureFlags = '',
  String supabaseUrl = '',
  String supabasePublishableKey = '',
}) {
  return Env.parse(
    appEnv: appEnv,
    apiBaseUrl: apiBaseUrl,
    appName: appName,
    enableLogging: '$enableLogging',
    featureFlags: featureFlags,
    supabaseUrl: supabaseUrl,
    supabasePublishableKey: supabasePublishableKey,
  );
}
