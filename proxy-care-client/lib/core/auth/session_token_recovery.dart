import '../network/access_token_provider.dart';
import 'authentication_session.dart';

/// Implements the 401 recovery `AuthInterceptor` uses, on top of an
/// [AuthenticationSession].
///
/// 1. If the session already holds a different token than the rejected one
///    (the SDK refreshed in the meantime), that token is returned and no
///    refresh happens.
/// 2. Otherwise the session is asked to refresh. Concurrent calls reach the
///    SDK, which de-duplicates refreshes of the same refresh token; nothing
///    here coordinates or schedules refreshes.
/// 3. If the refresh fails, null is returned and the original 401 stands.
///    An invalid session has already moved to `SessionExpired` and lost its
///    stored credentials; a transient failure leaves the session alone.
///
/// A 401 is not taken to mean the session is invalid: if the replayed
/// request is rejected again, that second 401 is returned to the caller
/// and the session is kept.
final class SessionTokenRecovery implements UnauthorizedRecovery {
  /// Creates recovery for [session].
  const SessionTokenRecovery(this.session);

  /// The session to read and refresh.
  final AuthenticationSession session;

  @override
  Future<String?> recoverAccessToken({required String rejectedToken}) async {
    final current = await session.getAccessToken();
    if (current != null && current != rejectedToken) return current;
    if (current == null) return null;

    try {
      await session.refreshSession();
    } on SessionRefreshException {
      return null;
    }
    final refreshed = await session.getAccessToken();
    return refreshed == rejectedToken ? null : refreshed;
  }
}
