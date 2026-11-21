# core/security

Security infrastructure: secure storage (`flutter_secure_storage`) wrappers
and token persistence.

- `secure_key_value_store.dart`: `SecureKeyValueStore`, the only persistent
  store for credentials, and its `flutter_secure_storage` implementation
  (Android Keystore + AES-GCM, iOS Keychain, web WebCrypto). Errors are
  `SecureStorageException`s; there is no insecure fallback.
- Callers depend on the interface, never on `FlutterSecureStorage`
  directly, so tests can substitute fakes. See SECURITY.md.
- Never log secrets or tokens.
