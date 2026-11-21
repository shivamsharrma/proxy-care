# Authentication

Supabase Auth is the identity provider. The Spring Boot backend is the
application API and validates the Supabase access tokens it receives. This
document covers the client side. No sign-in, sign-out or registration
screens exist yet; this is infrastructure only.

SDK: `supabase_flutter` 2.18.3 (the latest stable release; the 3.x line is a
breaking rewrite and still in prerelease). The behaviour described below was
checked in the 2.18.3 source.

## Architecture

```text
            Presentation / features
                     │  AuthenticationState, AuthenticationSession
                     ▼
      core/di/auth_providers.dart  (Riverpod)
                     │
      core/auth  ────┼── AuthenticationSession (interface)
                     │     └─ SupabaseAuthenticationSession ── Supabase Auth SDK
                     │                                          (GoTrueClient)
                     │                                               │
                     │     SecureSupabaseLocalStorage ◄──────────────┘ persists
                     │     SecureGotrueAsyncStorage   ◄──────────────┘ PKCE
                     │                │
                     │                ▼
      core/security  └──► SecureKeyValueStore ── flutter_secure_storage
                                                  ├ Android: Keystore + AES-GCM
                                                  ├ iOS: Keychain
                                                  └ web: WebCrypto + browser storage

      core/network:  AuthInterceptor ── AccessTokenProvider   ◄─ AuthenticationSession
                                     └─ UnauthorizedRecovery  ◄─ SessionTokenRecovery
```

Boundaries (enforced by `test/architecture/dependency_rules_test.dart`):

- Supabase SDK types appear only in `core/auth/supabase/` and `core/di/`.
- `flutter_secure_storage` appears only in `core/security/`.
- `core/network` never imports `core/auth` or Supabase: the interceptor only
  sees `AccessTokenProvider` and `UnauthorizedRecovery`.
- `AuthenticationState` and the authorization types are pure Dart, so the
  domain layer may use them.

## Who owns what

| Responsibility | Owner |
| --- | --- |
| Access-token issue, refresh-token rotation | Supabase Auth |
| Automatic refresh before expiry (10 s ticker, 30 s margin) | Supabase SDK |
| Pausing refresh in the background, resuming in the foreground | Supabase SDK (`WidgetsBindingObserver`) |
| De-duplicating concurrent refreshes of the same refresh token | Supabase SDK |
| Signing out when a refresh token is rejected | Supabase SDK (`SignOutReason.sessionExpired`) |
| Persisting and restoring the session | Supabase SDK, through our secure `LocalStorage` |
| Where the session is stored | `SecureSupabaseLocalStorage` → `SecureKeyValueStore` |
| Mapping SDK events to app states | `SupabaseAuthenticationSession` |
| Attaching the token to API requests; one replay after a 401 | `AuthInterceptor` |
| Deciding which token to replay with | `SessionTokenRecovery` |

The app has no refresh scheduler, no refresh-token store and no refresh
coordinator of its own.

## Initialization

`bootstrap()` (inside the guarded zone, before `runApp`):

1. Creates the provider container.
2. Awaits `supabaseAuthClientProvider`, which calls `initializeSupabase` once:
   `Supabase.initialize(url, publishableKey, authOptions:
   secureAuthOptions(...), debug: false)`. The secure `LocalStorage` and PKCE
   storage are passed in the options, so they are in place before the SDK
   reads any session. The SDK's own debug logging is off.
3. Calls `restoreSession()`, which aligns the app state with the session the
   SDK restored (no network call, no refresh).

Settings come from the environment (`SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY`; see README). Without them, a development build
runs signed out (`UnconfiguredAuthenticationSession`) and Supabase is not
initialized. Staging and production require them, and `Env` rejects secret
(`sb_secret_…`) and service-role keys.

## Session storage

`SecureSupabaseLocalStorage` implements the SDK's `LocalStorage`
(`initialize`, `hasAccessToken`, `accessToken`, `persistSession`,
`removePersistedSession`). The SDK writes the **complete session** (access
token, refresh token, expiry, user) as one JSON string after every sign-in
and refresh; it is stored under one secure key,
`proxycare.supabase.session`. Access and refresh tokens are never stored
separately.

`SecureGotrueAsyncStorage` does the same for PKCE code verifiers (by default
the SDK would also put those in SharedPreferences).

Errors:

| Operation | On failure |
| --- | --- |
| Read (start-up restore) | Reported; treated as no stored session, so the user signs in again. Nothing is read from another store. |
| Write (after sign-in / refresh) | Reported and rethrown to the SDK (which logs it). The in-memory session keeps working; it is not persisted. |
| Delete (sign-out, expiry) | Reported and rethrown. |
| PKCE read / write / delete | Reported and rethrown: the sign-in flow fails visibly. |

There is no fallback store. Platform details are in SECURITY.md.

## States

`AuthenticationState` (sealed), exposed by `authenticationStateProvider`:

| State | Meaning |
| --- | --- |
| `AuthenticationInitializing` | Start-up; the stored session is not checked yet |
| `Authenticated(user, expiresAt)` | Signed in; `expiresAt` is the access-token expiry |
| `Unauthenticated` | Not signed in, or signed out on purpose |
| `SessionExpired` | The session ended without the user asking (refresh token rejected, stored session unusable); sign in again |

SDK event → state (all transitions in `SupabaseAuthenticationSession`):

| SDK event | State |
| --- | --- |
| `initialSession` with / without a session | `Authenticated` / `Unauthenticated` |
| `signedIn`, `tokenRefreshed`, `userUpdated`, `passwordRecovery`, `mfaChallengeVerified` | `Authenticated` (updated user / expiry) |
| `signedOut`, reason `userInitiated` (or none) | `Unauthenticated` |
| `signedOut`, reason `sessionExpired` or `sessionMissing` | `SessionExpired`; stored credentials removed |
| `userDeleted` (deprecated, never sent) | follows its session (none → `Unauthenticated`) |
| stream error (for example no network during a refresh) | Reported; state kept (an invalid session is followed by a `signedOut` event) |

Roles on `AuthenticatedUser` are read by a `RoleReader` from `app_metadata`
only (never `user_metadata`, which users can edit). The claim layout is not
agreed with the backend yet, so the default reads no roles.

## Dio integration

`AuthInterceptor` (see ARCHITECTURE.md, "Networking"):

- **Request:** attaches `Authorization: Bearer <token>` from
  `AccessTokenProvider` (the session). No token → no header. No token for
  `skipAuth` requests, paths in `PublicEndpoints` (empty for now) or any
  other origin than `API_BASE_URL`. `getAccessToken` asks the SDK to refresh
  first when the token is within the SDK's 30 s expiry margin.
- **401** on a request that carried a token: `SessionTokenRecovery`
  1. returns the current token if it differs from the rejected one (the
     SDK already refreshed: no new refresh);
  2. otherwise calls `refreshSession()` on the SDK (de-duplicated by the SDK
     across concurrent 401s) and returns the new token;
  3. returns nothing if the refresh fails.

  With a new token the request is replayed **once** (headers, query,
  cancel token and idempotency key kept; multipart bodies recreated;
  consumed streams never replayed). The replay is marked, so a second 401
  is final and returned to the caller as `UnauthorizedException`.
- A 401 does not by itself end the session: an endpoint can reject a valid
  token for its own reasons. The session ends only when the SDK reports the
  session invalid (rejected refresh token), which moves the state to
  `SessionExpired` and clears storage.
- Supabase's own requests use the SDK's HTTP client and never pass through
  the app's Dio or its interceptor.

## Errors

- `SessionRefreshException(sessionInvalid: true)`: the session cannot be
  renewed; the state is `SessionExpired`, storage is cleared.
- `SessionRefreshException(sessionInvalid: false)`: transient (network);
  the session is kept and the SDK will retry.
- Storage failures: `SecureStorageException` (operation and key name only).
- None of these messages contain tokens; the error reporter receives only
  error types and messages, and crash reports only error types.

## Invalidating the session

`invalidateSession()` signs out locally (`signOut(scope: local)`), deletes
the stored session even if the SDK call fails, and moves to
`Unauthenticated`. It never throws. Sign-out does not revoke issued access
tokens on the server immediately (see SECURITY.md).

## Lifecycle

The SDK pauses its refresh ticker when the app is paused or detached and
restarts it on resume; on resume it refreshes only if the token is close to
expiry. The app adds no lifecycle observer and no refresh on resume
(`supabase_authentication_session_test.dart` checks this).

## Authorization foundation

`core/auth/authorization/`: `Role`, `Permission`, `AuthorizationDecision`
(`Allowed` / `Denied(reason)`), `PermissionEvaluator`,
`RolePermissionPolicy` and `AuthorizationService`
(`authorizationServiceProvider`, which grants nothing by default). No roles
or permissions are defined. These decide only what the UI offers; the API
enforces access.

## Biometric integration point

`BiometricGate` (`biometricGateProvider`, `DisabledBiometricGate` in the
MVP). A later implementation (for example with `local_auth`) would:

1. after a cold start, or after a configurable time in the background,
   check `isAvailable()` and, if the user opted in, call `confirm()` before
   showing signed-in content;
2. on `rejected`, keep the content hidden and offer to retry or sign out;
3. never read, return or store tokens: the session stays in secure storage
   and is used only by the SDK and the API client.

Optionally, the secure store's platform options can add biometric access
control to the session entry itself (Android `enforceBiometrics`, iOS
access-control flags). That would also block background refreshes, so it is
not enabled.

## Manual Supabase configuration still required

- Create the Supabase projects (staging, production) and put each project
  URL and **publishable** key (`sb_publishable_…`) in
  `config/env/<env>.json`. Never use a secret or service-role key.
- Enable the sign-in methods the product needs (for example phone OTP,
  backlog PL-04 and LL-07) and the SMS provider.
- Use asymmetric JWT signing keys, so the backend can verify tokens through
  the JWKS endpoint (see SECURITY.md).
- Set redirect URLs (Authentication → URL Configuration) for the web origin
  and, later, the mobile deep-link scheme.
- Keep the access-token expiry at the default 1 hour, and leave refresh-token
  reuse detection on.
- Decide where roles live (an `app_metadata` field or a Custom Access Token
  Hook claim) and implement the `RoleReader` accordingly.
