# core/auth

Authentication infrastructure over Supabase Auth. See AUTHENTICATION.md.

- `authentication_state.dart`: `AuthenticationState` (initializing,
  authenticated, unauthenticated, session expired) and `AuthenticatedUser`.
  Pure Dart.
- `authentication_session.dart`: `AuthenticationSession`, the app-facing
  session interface, `SessionRefreshException`, and the unconfigured session.
- `supabase/`: the only code that touches the Supabase SDK: the session
  implementation, secure `LocalStorage` and PKCE storage, initialization.
- `authorization/`: roles, permissions and decisions (UI hints only).
- `biometric_gate.dart`: optional biometric unlock point (disabled).

No screens and no business rules live here.
