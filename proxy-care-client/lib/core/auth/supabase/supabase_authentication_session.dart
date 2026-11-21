import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../error/error_reporter.dart';
import '../authentication_session.dart';
import '../authentication_state.dart';
import '../authorization/authorization.dart';
import 'secure_supabase_storage.dart';

/// Reads a user's roles from server-controlled claims. The claim that will
/// carry roles is not agreed with the backend yet, so the default reads
/// none. Never read roles from `user_metadata`: users can edit it.
typedef RoleReader = Set<Role> Function(Map<String, dynamic> appMetadata);

Set<Role> _noRoles(Map<String, dynamic> appMetadata) => const {};

/// [AuthenticationSession] over Supabase Auth ([GoTrueClient]).
///
/// The SDK does the work: it persists the session through
/// [SecureSupabaseLocalStorage], restores it at start-up, refreshes it
/// ahead of expiry (pausing while the app is in the background and
/// resuming in the foreground), de-duplicates concurrent refreshes and
/// signs out when a refresh token is rejected. This class only listens to
/// its events, maps them to [AuthenticationState]s and forwards the few
/// explicit requests the app makes.
///
/// It never schedules refreshes and has no lifecycle observer of its own.
final class SupabaseAuthenticationSession implements AuthenticationSession {
  /// Creates a session over [auth]; call [start] once.
  SupabaseAuthenticationSession({
    required this.auth,
    required this.storage,
    this.reporter,
    this.roleReader = _noRoles,
  });

  /// The SDK's auth client.
  final GoTrueClient auth;

  /// The secure session storage (for explicit cleanup).
  final SecureSupabaseLocalStorage storage;

  /// Receives auth stream and storage errors.
  final ErrorReporter? reporter;

  /// Reads roles from `app_metadata`.
  final RoleReader roleReader;

  final StreamController<AuthenticationState> _changes =
      StreamController.broadcast();
  StreamSubscription<AuthState>? _subscription;
  AuthenticationState _state = const AuthenticationInitializing();

  @override
  AuthenticationState get currentState => _state;

  @override
  Stream<AuthenticationState> get authStateChanges => _changes.stream;

  @override
  DateTime? get sessionExpiresAt => _expiry(auth.currentSession);

  /// Subscribes to the SDK's auth events. The SDK replays its latest event
  /// to new listeners, so the initial session is not missed.
  void start() {
    _subscription ??= auth.onAuthStateChange.listen(
      _onAuthState,
      onError: _onAuthError,
    );
  }

  /// Stops listening and closes [authStateChanges].
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _changes.close();
  }

  @override
  Future<String?> getAccessToken() async {
    final session = auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      // Expired or about to: let the SDK refresh (it de-duplicates); on a
      // transient failure use what we have and let the API decide.
      try {
        await refreshSession();
      } on SessionRefreshException catch (error) {
        if (error.sessionInvalid) return null;
      }
      return auth.currentSession?.accessToken ?? session.accessToken;
    }
    return session.accessToken;
  }

  @override
  Future<void> restoreSession() async {
    // Supabase.initialize has already loaded the persisted session; only
    // the state needs to agree with it. No refresh happens here.
    if (_state is AuthenticationInitializing) {
      _setState(_stateFor(auth.currentSession));
    }
  }

  @override
  Future<void> refreshSession() async {
    try {
      await auth.refreshSession();
    } on AuthSessionMissingException catch (error) {
      await _expire();
      throw SessionRefreshException(sessionInvalid: true, cause: error);
    } on AuthRetryableFetchException catch (error) {
      throw SessionRefreshException(sessionInvalid: false, cause: error);
    } on AuthException catch (error) {
      // The SDK signed out already (refresh token rejected); make sure the
      // state and storage agree.
      await _expire();
      throw SessionRefreshException(sessionInvalid: true, cause: error);
    } on Object catch (error) {
      // Anything else (an unexpected failure) is treated as transient.
      throw SessionRefreshException(sessionInvalid: false, cause: error);
    }
  }

  @override
  Future<void> invalidateSession() async {
    try {
      await auth.signOut(scope: SignOutScope.local);
    } on Object catch (error, stackTrace) {
      reporter?.report(error, stackTrace, context: 'auth');
    }
    await _clearStoredCredentials();
    _setState(const Unauthenticated());
  }

  void _onAuthState(AuthState data) {
    final next = switch (data.event) {
      AuthChangeEvent.signedOut => switch (data.signOutReason) {
        SignOutReason.sessionExpired ||
        SignOutReason.sessionMissing => const SessionExpired(),
        _ => const Unauthenticated(),
      },
      // initialSession, signedIn, tokenRefreshed, userUpdated,
      // passwordRecovery, mfaChallengeVerified and (deprecated, never sent)
      // userDeleted: the state follows the session they carry.
      _ => _stateFor(data.session),
    };
    if (next is SessionExpired) unawaited(_clearStoredCredentials());
    _setState(next);
  }

  void _onAuthError(Object error, StackTrace stackTrace) {
    // Retryable failures (no network) keep the session; the SDK tries
    // again. An invalid session is followed by a signedOut event, which
    // moves the state. Either way the error is reported, without tokens.
    reporter?.report(error, stackTrace, context: 'auth');
    if (_state is AuthenticationInitializing) {
      _setState(_stateFor(auth.currentSession));
    }
  }

  Future<void> _expire() async {
    await _clearStoredCredentials();
    _setState(const SessionExpired());
  }

  Future<void> _clearStoredCredentials() async {
    try {
      await storage.removePersistedSession();
    } on Object {
      // Already reported by the storage adapter.
    }
  }

  AuthenticationState _stateFor(Session? session) {
    if (session == null) return const Unauthenticated();
    final user = session.user;
    return Authenticated(
      user: AuthenticatedUser(
        id: user.id,
        email: user.email,
        phone: user.phone,
        isAnonymous: user.isAnonymous,
        roles: roleReader(user.appMetadata),
      ),
      expiresAt: _expiry(session),
    );
  }

  static DateTime? _expiry(Session? session) {
    final seconds = session?.expiresAt;
    return seconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  void _setState(AuthenticationState next) {
    if (_sameState(_state, next)) return;
    _state = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  static bool _sameState(AuthenticationState a, AuthenticationState b) =>
      switch ((a, b)) {
        (
          Authenticated(user: final u1, expiresAt: final e1),
          Authenticated(user: final u2, expiresAt: final e2),
        ) =>
          u1 == u2 && e1 == e2,
        _ => a.runtimeType == b.runtimeType,
      };
}
