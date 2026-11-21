import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env.dart';
import '../../error/error_reporter.dart';
import '../../security/secure_key_value_store.dart';
import 'secure_supabase_storage.dart';

/// Initializes Supabase once, with secure storage registered before the
/// SDK restores any session. Called only through
/// `supabaseAuthClientProvider` (bootstrap awaits it); nothing else
/// initializes Supabase.
///
/// Returns null when [env] has no Supabase settings (a development build
/// without them): the app then runs signed out.
Future<GoTrueClient?> initializeSupabase({
  required Env env,
  required SecureKeyValueStore store,
  ErrorReporter? reporter,
}) async {
  final url = env.supabaseUrl;
  final key = env.supabasePublishableKey;
  if (url == null || key == null) return null;

  final supabase = await Supabase.initialize(
    url: url.toString(),
    publishableKey: key,
    authOptions: secureAuthOptions(store: store, reporter: reporter),
    // The SDK's own debug logging is off: the app logs through its logger,
    // and SDK records could include auth details.
    debug: false,
  );
  return supabase.client.auth;
}

/// The auth options: the session and PKCE verifiers go to secure storage;
/// the SDK keeps its defaults for everything else (PKCE flow, automatic
/// refresh, lifecycle handling, session detection in redirect URLs).
FlutterAuthClientOptions secureAuthOptions({
  required SecureKeyValueStore store,
  ErrorReporter? reporter,
}) => FlutterAuthClientOptions(
  localStorage: SecureSupabaseLocalStorage(store, reporter: reporter),
  pkceAsyncStorage: SecureGotrueAsyncStorage(store, reporter: reporter),
);
