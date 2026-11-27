# Security

Client-side security guarantees and the requirements they place on the
backend. The client is never a security boundary: every protected resource
must be checked by the Spring Boot API.

## Token storage guarantees

- The only credential the client persists is the Supabase session (access
  token, refresh token, expiry, user), stored as **one** entry by
  `SecureSupabaseLocalStorage` through `SecureKeyValueStore`
  (`flutter_secure_storage` 11.2.0). PKCE code verifiers use the same store.
- Tokens are never written to SharedPreferences, files, logs or crash
  reports. `supabase_flutter` depends on `shared_preferences` for its
  default storage, but the app always passes its own secure storage, and an
  architecture test fails if any app code imports `shared_preferences` or
  uses the SDK's default storage classes.
- No insecure fallback: a storage failure is reported; reads fall back to
  "no session" (the user signs in again), writes and deletes fail.
- Session invalidation and session expiry delete the stored session.
- Tokens are not exposed to UI code: widgets get `AuthenticationState`,
  which carries no tokens. The access token is only read by the API client.

## Android secure storage

- `flutter_secure_storage` 10+ no longer uses Jetpack
  `EncryptedSharedPreferences`. The app sets AES-GCM for both the key cipher
  (the AES key lives in the **Android Keystore**) and the storage cipher
  (`FlutterSecureKeyValueStore.androidOptions`).
- `resetOnError` (the plugin default, kept) erases entries whose Keystore key
  can no longer unwrap them; the user signs in again instead of the app
  failing on every start.
- **Backups are off** (configured): Keystore keys never leave the device,
  so backed-up ciphertext could not be decrypted after a restore and would
  cause `Failed to unwrap key` errors. `AndroidManifest.xml` sets
  `android:allowBackup="false"` and `android:fullBackupContent="false"`
  (API ≤ 30), and `res/xml/data_extraction_rules.xml` excludes all data from
  cloud backup and device-to-device transfer (API 31+).

## iOS Keychain

- Entries are Keychain items with accessibility
  `first_unlock_this_device` (`FlutterSecureKeyValueStore.iosOptions`):
  readable after the device has been unlocked once since boot (so a refresh
  can run in the background), never synced to iCloud Keychain
  (`synchronizable: false`) and not restored to another device.
- No Keychain entitlement or access group is needed: the app uses only its
  own default Keychain items.
- **Uninstall (pending):** iOS keeps Keychain items after the app is
  deleted, so a reinstall can find the previous session. Planned: clear the
  secure store on the first launch after installation, using a non-secret
  "first run" marker in app storage (needs a small file-storage dependency
  or a native marker; not added in the MVP foundation). Until then the old
  session is restored and is either still valid or rejected by the server
  on its next refresh.

## Web

`flutter_secure_storage` on web encrypts values with WebCrypto and keeps them
in the browser's storage, with the key in the same browser. This was chosen
knowingly and is **weaker** than the mobile stores: any script running on the
page origin (for example through an XSS flaw or a compromised dependency) can
use the stored session. It also works only on HTTPS or localhost.
Mitigations to apply when deploying: a strict Content Security Policy, HTTP
Strict Transport Security, no third-party scripts on the app origin, and the
1-hour access-token expiry with refresh-token reuse detection left on.

## Token refresh and session invalidation

Summary of [AUTHENTICATION.md](AUTHENTICATION.md):

- **Refresh** is owned by the Supabase SDK: it refreshes before expiry,
  pauses in the background, de-duplicates concurrent refreshes and rotates
  the single-use refresh token. The app has no scheduler or token store of
  its own.
- **401 handling:** `AuthInterceptor` only attaches the token; it does not
  refresh or repeat a request. A 401 reaches the caller as
  `UnauthorizedException` and never ends the session by itself.
- **Invalidation:** a rejected refresh token ends the session
  (`SessionExpired`) and deletes the stored session; signing out
  (`invalidateSession`) signs out locally and deletes it even if the SDK
  call fails; `SessionCleanup` tasks (for example the push token) run
  whenever a session ends. Issued access tokens stay valid until they
  expire (1 hour), so the backend should check `session_id` for sensitive
  operations.

## Sensitive logging restrictions

- `LoggingInterceptor` logs only method, path, status, duration and
  correlation ID. No hosts, query values, headers or bodies; debug builds add
  masked headers and query parameter names only.
- All logging goes through `AppLogger` (`loggerProvider`); `print` is
  rejected by the analyzer. Production logs warnings and errors only, and
  nothing when `ENABLE_LOGGING` is false (the production default). Log
  messages are constant text; data goes in structured fields.
- `Redactor` (`core/security/redactor.dart`) masks, by key name,
  `Authorization`, cookies, tokens (access, refresh, id), passwords,
  secrets, API keys, OTPs and PINs, identity and payment details, contact
  details and health fields; and, in any text, JWTs, bearer tokens, email
  addresses and runs of 9 or more digits (phone, Aadhaar, account, card).
  The logger applies it to every message, field and error text.
- Outside development builds, errors are logged as their type only.
- The Supabase SDK's debug logging is disabled (`debug: false`).
- Crash reports carry only the error type, stack trace and context, never the
  error message or object.
- `AuthenticatedUser.toString()` prints the user ID only;
  `SecureStorageException` names the key, never the value.

## Handling sensitive data (conventions for features)

- **PII and health data stay out of side channels:** not in logs (never
  interpolate data into messages; use field names the `Redactor` masks),
  not in analytics, not in crash reports, not in URLs (paths carry opaque
  IDs, never names or phone numbers).
- **Error reporting:** report errors through `ErrorReporter`. It logs
  through the redacting logger and sends crash services only a
  `CrashReport` (type, stack, context). Never put user data in the
  messages of exceptions you throw.
- **Analytics:** features call `analyticsServiceProvider`, which drops
  events with non-snake_case names, and parameters with sensitive keys,
  non-primitive values or values that look like personal data. Review
  event parameters like API fields.
- **Session cleanup:** anything that keeps per-user data (caches, drafts,
  push tokens, a vendor user ID) registers a task with
  `sessionCleanupProvider`. Tasks run when the session ends (sign-out or
  expiry); a failure is reported and the other tasks still run. Tokens in
  secure storage are cleared by the authentication session itself.
- **Push notifications:** payloads carry IDs only (no names or health
  details: they can appear on a lock screen). Tapped payloads are validated
  by `NavigationPayload` before navigation.

## Device information

The app collects only the platform (`AppPlatform`: web, android, ios),
needed to register a push token. It does not read device IDs, the
advertising ID, the model, the OS version, location or installed apps.
Connectivity is used on the device only, to explain failures, and is not
sent anywhere. Any other device data needs a privacy review and updates to
this section and the store privacy declarations.

## Platform security considerations

- **Transport:** release builds use https only (staging and production
  `API_BASE_URL` must be https; Android blocks cleartext by default and
  allows it only in debug builds for a local backend; iOS App Transport
  Security is left at its defaults).
- **Deep links** are data from outside: only `https` links on configured
  hosts are opened, every incoming location is sanitized, and links pass
  the same authentication and authorization guards as in-app navigation.
  Identifiers in links are opaque IDs.
- **Notifications:** payloads are validated before navigation and carry IDs
  only (lock screens can show them).
- **Release hardening still to decide:** Android R8/obfuscation and
  `--split-debug-info` with archived symbols, iOS privacy manifest, and
  screenshot protection for sensitive screens (when they exist).
- The client never enforces access: every permission is checked by the API.

## Dependency security

- Versions are pinned by the committed `pubspec.lock`; CI installs exactly
  them (`--enforce-lockfile` in the Android, iOS and Pages jobs) and fails
  if resolving would change it.
- Add a dependency only when the platform or an existing package cannot do
  the job; prefer Dart/Flutter team and widely used, maintained packages;
  review what it pulls in (`flutter pub deps`) and what it collects
  (analytics, crash or ad SDKs need a privacy review).
- Vendor SDKs stay behind interfaces in one folder each (architecture tests
  enforce this for `supabase_flutter`, `flutter_secure_storage`, `logger`
  and `connectivity_plus`).
- `shared_preferences` is present only as a transitive dependency of
  `supabase_flutter`; app code may not use it (test enforced).
- Review `flutter pub outdated` regularly and apply security releases
  promptly; GitHub Actions are pinned by major version.

## Environment configuration

- `config/env/*.json` holds non-sensitive values only: the API URL, the
  Supabase URL and the Supabase **publishable** key (safe to ship; Row Level
  Security limits what it can reach).
- `Env` rejects secret keys (`sb_secret_…`) and legacy service-role JWTs, so a
  build containing one fails. Secret keys, the JWT secret, database
  credentials, payment secrets and signing credentials stay in backend
  infrastructure or CI secret management.
- `--dart-define` values are compiled into the app and readable by anyone
  with the binary; they are not secret storage.

## Backend JWT validation requirements (Spring Boot)

The client sends the Supabase access token as `Authorization: Bearer …` on
every API request that is not public. The backend must, on every request:

1. Verify the signature against the project's JWKS
   (`https://<project-ref>.supabase.co/auth/v1/.well-known/jwks.json`), which
   requires **asymmetric** JWT signing keys (ES256/RS256) in the Supabase
   project. Match the token's `kid` and `alg`; refresh the cached JWKS at
   least every 10 minutes and on an unknown `kid` (key rotation).
2. Check `iss` = `https://<project-ref>.supabase.co/auth/v1`,
   `aud` = `authenticated`, and that `exp` is in the future.
3. Use `sub` as the user ID. Take roles only from server-controlled claims
   (`app_metadata` or a Custom Access Token Hook), never from
   `user_metadata`, which users can edit.
4. Enforce every permission on the server; client authorization is a hint.
5. For the most sensitive actions, also check that the token's `session_id`
   still exists, because sign-out does not invalidate already-issued access
   tokens before they expire.
6. Answer an invalid or expired token with 401 and a missing permission with
   403 (the client recovers once from a 401 and never retries a 403), using
   the backend's `ApiError` body.

These are assumptions about the backend; no endpoint or authentication
contract is defined in this repository.
