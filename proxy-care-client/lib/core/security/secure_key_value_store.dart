import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The only persistent store for credentials. Backed by the platform's
/// secure storage; there is no other implementation and no fallback.
///
/// Every failure is raised as [SecureStorageException], whose message never
/// contains the key's value.
abstract interface class SecureKeyValueStore {
  /// The value stored under [key], or null.
  Future<String?> read(String key);

  /// Stores [value] under [key], replacing any previous value.
  Future<void> write(String key, String value);

  /// Removes [key]. Removing a missing key is not an error.
  Future<void> delete(String key);
}

/// The secure-storage operation that failed.
enum SecureStorageOperation { read, write, delete }

/// A secure-storage operation failed. The value is never included.
final class SecureStorageException implements Exception {
  /// Creates an exception for [operation] on [key].
  const SecureStorageException(this.operation, this.key, {this.cause});

  /// What failed.
  final SecureStorageOperation operation;

  /// Which entry (a fixed name, never a secret).
  final String key;

  /// The platform error, for logs. Platform messages describe the failure
  /// (for example a Keychain status), not stored values.
  final Object? cause;

  @override
  String toString() =>
      'SecureStorageException: ${operation.name} of "$key" failed';
}

/// [SecureKeyValueStore] backed by `flutter_secure_storage`.
///
/// * **Android:** values are encrypted with AES-GCM; the AES key is held in
///   the Android Keystore. `resetOnError` erases entries whose key can no
///   longer be unwrapped (for example data restored from a backup onto
///   another device), which signs the user out instead of failing forever.
/// * **iOS:** values are Keychain items, accessible after the first unlock
///   on this device only (`first_unlock_this_device`): they are not synced
///   to iCloud and not migrated to another device.
/// * **Web:** values are encrypted with WebCrypto and kept in the browser's
///   storage, with the key in the same browser. This is weaker than the
///   mobile stores (script running on the page can use it); see
///   SECURITY.md.
final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  /// Creates a store with the app's platform options.
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: androidOptions,
            iOptions: iosOptions,
            webOptions: webOptions,
          );

  final FlutterSecureStorage _storage;

  /// Android: AES-GCM with a Keystore-held key.
  static const AndroidOptions androidOptions = AndroidOptions(
    keyCipherAlgorithm: KeyCipherAlgorithm.AES_GCM_NoPadding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  );

  /// iOS: this device only, available after the first unlock (so a refresh
  /// can run while the app is in the background), never synchronized.
  static const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// Web: an app-specific database; persists across tabs and reloads.
  static const WebOptions webOptions = WebOptions(
    dbName: 'ProxyCareSecureStorage',
    publicKey: 'ProxyCareSecureStorage',
  );

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object catch (error) {
      throw SecureStorageException(
        SecureStorageOperation.read,
        key,
        cause: error,
      );
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Object catch (error) {
      throw SecureStorageException(
        SecureStorageOperation.write,
        key,
        cause: error,
      );
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on Object catch (error) {
      throw SecureStorageException(
        SecureStorageOperation.delete,
        key,
        cause: error,
      );
    }
  }
}
