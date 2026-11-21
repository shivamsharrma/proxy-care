import '../network/access_token_provider.dart';
import 'authentication_state.dart';

/// The app's view of the signed-in session. Implemented over Supabase Auth
/// (`SupabaseAuthenticationSession`); nothing outside `core/auth` and
/// `core/di` sees the SDK.
///
/// The identity provider owns the token lifecycle: refresh-token rotation,
/// automatic refresh, concurrent-refresh coordination and persistence. This
/// interface only reads that state and asks for a refresh when the API
/// rejected a token.
abstract interface class AuthenticationSession implements AccessTokenProvider {
  /// The current state.
  AuthenticationState get currentState;

  /// Every state change, starting after [currentState].
  Stream<AuthenticationState> get authStateChanges;

  /// When the current access token expires, or null when signed out.
  DateTime? get sessionExpiresAt;

  /// The current access token; null when signed out. If the token is about
  /// to expire, the identity provider is asked to refresh first.
  @override
  Future<String?> getAccessToken();

  /// Brings [currentState] in line with the session restored by the
  /// identity provider at start-up. Does not refresh.
  Future<void> restoreSession();

  /// Asks the identity provider to refresh the session now.
  ///
  /// Throws [SessionRefreshException]. When the session itself is invalid
  /// (rejected refresh token), the state becomes [SessionExpired] and
  /// stored credentials are removed; a transient failure (network) leaves
  /// the session as it is.
  Future<void> refreshSession();

  /// Ends the session locally: signs out of the identity provider, removes
  /// every stored credential and moves to [Unauthenticated]. Never throws.
  Future<void> invalidateSession();
}

/// A refresh did not produce a new session.
final class SessionRefreshException implements Exception {
  /// Creates an exception; [sessionInvalid] tells a rejected session from a
  /// transient failure.
  const SessionRefreshException({required this.sessionInvalid, this.cause});

  /// True when the session can no longer be refreshed (sign in again);
  /// false for transient failures such as no network.
  final bool sessionInvalid;

  /// The identity provider's error, for logs. Contains no tokens.
  final Object? cause;

  @override
  String toString() =>
      'SessionRefreshException(sessionInvalid: $sessionInvalid)';
}

/// The session when authentication is not configured (a development build
/// without Supabase settings): always signed out.
final class UnconfiguredAuthenticationSession implements AuthenticationSession {
  /// Creates an unconfigured session.
  const UnconfiguredAuthenticationSession();

  @override
  AuthenticationState get currentState => const Unauthenticated();

  @override
  Stream<AuthenticationState> get authStateChanges => const Stream.empty();

  @override
  DateTime? get sessionExpiresAt => null;

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> refreshSession() async =>
      throw const SessionRefreshException(sessionInvalid: true);

  @override
  Future<void> invalidateSession() async {}
}
