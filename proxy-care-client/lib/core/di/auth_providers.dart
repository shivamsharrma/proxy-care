import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/authentication_session.dart';
import '../auth/authentication_state.dart';
import '../auth/authorization/authorization.dart';
import '../auth/biometric_gate.dart';
import '../auth/supabase/secure_supabase_storage.dart';
import '../auth/supabase/supabase_authentication_session.dart';
import '../auth/supabase/supabase_initializer.dart';
import '../security/secure_key_value_store.dart';
import 'core_providers.dart';

// Authentication providers. Supabase types appear only here and in
// core/auth/supabase; everything else uses AuthenticationSession and
// AuthenticationState.

/// The secure store for credentials.
final secureKeyValueStoreProvider = Provider<SecureKeyValueStore>(
  (ref) => FlutterSecureKeyValueStore(),
);

/// Initializes Supabase (once) and yields its auth client, or null when the
/// environment has no Supabase settings. Bootstrap awaits it before the
/// first frame; it is the only place Supabase is initialized.
final supabaseAuthClientProvider = FutureProvider<GoTrueClient?>(
  (ref) => initializeSupabase(
    env: ref.watch(envProvider),
    store: ref.watch(secureKeyValueStoreProvider),
    reporter: ref.watch(errorReporterProvider),
  ),
);

/// The app's authentication session. Requires [supabaseAuthClientProvider]
/// to have completed (bootstrap guarantees it).
final authenticationSessionProvider = Provider<AuthenticationSession>((ref) {
  final auth = ref.watch(supabaseAuthClientProvider).requireValue;
  if (auth == null) return const UnconfiguredAuthenticationSession();

  final reporter = ref.watch(errorReporterProvider);
  final session = SupabaseAuthenticationSession(
    auth: auth,
    storage: SecureSupabaseLocalStorage(
      ref.watch(secureKeyValueStoreProvider),
      reporter: reporter,
    ),
    reporter: reporter,
  )..start();
  ref.onDispose(session.dispose);
  return session;
});

/// The current authentication state, kept in sync with the session.
final authenticationStateProvider =
    NotifierProvider<AuthenticationStateController, AuthenticationState>(
      AuthenticationStateController.new,
    );

/// Mirrors [AuthenticationSession.authStateChanges]. State transitions are
/// decided in one place, the session; this only exposes them to widgets
/// and cancels its subscription when the provider is disposed.
class AuthenticationStateController extends Notifier<AuthenticationState> {
  @override
  AuthenticationState build() {
    final session = ref.watch(authenticationSessionProvider);
    final subscription = session.authStateChanges.listen(
      (next) => state = next,
    );
    ref.onDispose(subscription.cancel);
    return session.currentState;
  }
}

/// Client-side permission checks (UI hints only; the API enforces access).
final authorizationServiceProvider = Provider<AuthorizationService>(
  (ref) => const AuthorizationService(RolePermissionPolicy.none),
);

/// Optional biometric unlock; disabled in the MVP.
final biometricGateProvider = Provider<BiometricGate>(
  (ref) => const DisabledBiometricGate(),
);
