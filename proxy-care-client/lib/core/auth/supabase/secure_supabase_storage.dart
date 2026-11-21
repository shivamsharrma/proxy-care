import 'package:supabase_flutter/supabase_flutter.dart';

import '../../error/error_reporter.dart';
import '../../security/secure_key_value_store.dart';

/// Storage keys of the Supabase entries in secure storage. Fixed names; the
/// values are secrets and are never logged.
abstract final class SupabaseStorageKeys {
  /// The complete serialized session (access token, refresh token, expiry,
  /// user), written by the SDK as one value.
  static const String session = 'proxycare.supabase.session';

  /// Prefix of PKCE code-verifier entries written during sign-in flows.
  static const String pkcePrefix = 'proxycare.supabase.pkce.';
}

/// Supabase's session [LocalStorage], backed by [SecureKeyValueStore].
///
/// Replaces the SDK default (SharedPreferences). The SDK persists the whole
/// session as one JSON string after every sign-in and refresh, restores it
/// at start-up and removes it on sign-out; this adapter only decides where
/// it lives. Access and refresh tokens are never stored separately.
///
/// Errors: a failed read is reported and treated as "no stored session"
/// (the user signs in again; nothing is read from anywhere else). A failed
/// write or delete is reported and rethrown to the SDK. There is no
/// fallback store.
final class SecureSupabaseLocalStorage extends LocalStorage {
  /// Creates the adapter over [store], reporting failures to [reporter].
  const SecureSupabaseLocalStorage(this.store, {this.reporter});

  /// Where the session is kept.
  final SecureKeyValueStore store;

  /// Receives storage failures (never the session itself).
  final ErrorReporter? reporter;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  /// Despite its name (from the SDK interface), returns the whole persisted
  /// session string.
  @override
  Future<String?> accessToken() async {
    try {
      final value = await store.read(SupabaseStorageKeys.session);
      return value == null || value.isEmpty ? null : value;
    } on SecureStorageException catch (error, stackTrace) {
      reporter?.report(error, stackTrace, context: 'secure-storage');
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) => _guard(
    () => store.write(SupabaseStorageKeys.session, persistSessionString),
  );

  @override
  Future<void> removePersistedSession() =>
      _guard(() => store.delete(SupabaseStorageKeys.session));

  Future<void> _guard(Future<void> Function() operation) async {
    try {
      await operation();
    } on SecureStorageException catch (error, stackTrace) {
      reporter?.report(error, stackTrace, context: 'secure-storage');
      rethrow;
    }
  }
}

/// Supabase's PKCE code-verifier storage, backed by [SecureKeyValueStore].
///
/// Replaces the SDK default (SharedPreferences) for the short-lived secret
/// used while exchanging an auth code for a session. Failures are reported
/// and rethrown, so a sign-in flow fails visibly instead of using a weaker
/// store.
final class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  /// Creates the adapter over [store].
  const SecureGotrueAsyncStorage(this.store, {this.reporter});

  /// Where verifiers are kept.
  final SecureKeyValueStore store;

  /// Receives storage failures.
  final ErrorReporter? reporter;

  static String _key(String key) => '${SupabaseStorageKeys.pkcePrefix}$key';

  @override
  Future<String?> getItem({required String key}) =>
      _guard(() => store.read(_key(key)));

  @override
  Future<void> setItem({required String key, required String value}) =>
      _guard(() => store.write(_key(key), value));

  @override
  Future<void> removeItem({required String key}) =>
      _guard(() => store.delete(_key(key)));

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on SecureStorageException catch (error, stackTrace) {
      reporter?.report(error, stackTrace, context: 'secure-storage');
      rethrow;
    }
  }
}
