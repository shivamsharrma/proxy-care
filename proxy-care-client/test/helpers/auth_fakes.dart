import 'dart:async';
import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/auth/authentication_session.dart';
import 'package:proxy_care_client/core/auth/authentication_state.dart';
import 'package:proxy_care_client/core/security/secure_key_value_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory [SecureKeyValueStore] whose operations can be made to fail.
final class FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) {
      throw SecureStorageException(SecureStorageOperation.read, key);
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) {
      throw SecureStorageException(SecureStorageOperation.write, key);
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDeletes) {
      throw SecureStorageException(SecureStorageOperation.delete, key);
    }
    values.remove(key);
  }
}

class MockGoTrueClient extends Mock implements GoTrueClient {}

/// An unsigned JWT-shaped token expiring at [expiresAt] (only the payload
/// is read by the SDK's `Session.expiresAt`).
String fakeJwt({required DateTime expiresAt, String id = 'a'}) {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.'
      '${part({'exp': expiresAt.millisecondsSinceEpoch ~/ 1000, 'jti': id})}.'
      'signature';
}

/// A Supabase session for user `user-1`.
Session fakeSession({
  DateTime? expiresAt,
  String tokenId = 'a',
  String? email = 'user@example.test',
}) {
  return Session(
    accessToken: fakeJwt(
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
      id: tokenId,
    ),
    refreshToken: 'refresh-$tokenId',
    tokenType: 'bearer',
    user: User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-11-14T10:00:00Z',
      email: email,
    ),
  );
}

/// An [AuthenticationSession] with scripted tokens and refresh outcomes.
class FakeAuthenticationSession implements AuthenticationSession {
  FakeAuthenticationSession({this.token, this.tokenAfterRefresh});

  final StreamController<AuthenticationState> changes =
      StreamController.broadcast();

  String? token;
  String? tokenAfterRefresh;
  SessionRefreshException? refreshError;
  int refreshes = 0;
  int invalidations = 0;

  @override
  AuthenticationState currentState = const AuthenticationInitializing();

  @override
  Stream<AuthenticationState> get authStateChanges => changes.stream;

  @override
  DateTime? get sessionExpiresAt => null;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<void> refreshSession() async {
    refreshes++;
    if (refreshError case final error?) throw error;
    token = tokenAfterRefresh;
  }

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> invalidateSession() async => invalidations++;

  void emit(AuthenticationState state) {
    currentState = state;
    changes.add(state);
  }
}
