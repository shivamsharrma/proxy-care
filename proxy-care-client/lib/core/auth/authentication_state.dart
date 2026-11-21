import 'authorization/authorization.dart';

/// Where the app stands with authentication. Pure Dart, free of any
/// identity-provider type, so domain and presentation can depend on it.
sealed class AuthenticationState {
  const AuthenticationState();

  /// Whether a user is signed in.
  bool get isAuthenticated => this is Authenticated;
}

/// Start-up: the persisted session has not been checked yet.
final class AuthenticationInitializing extends AuthenticationState {
  /// Creates the initializing state.
  const AuthenticationInitializing();
}

/// A user is signed in.
final class Authenticated extends AuthenticationState {
  /// Creates the signed-in state.
  const Authenticated({required this.user, this.expiresAt});

  /// The signed-in user.
  final AuthenticatedUser user;

  /// When the current access token expires; the identity provider renews it
  /// before then.
  final DateTime? expiresAt;
}

/// Nobody is signed in (never signed in, or signed out on purpose).
final class Unauthenticated extends AuthenticationState {
  /// Creates the signed-out state.
  const Unauthenticated();
}

/// The session ended without the user asking: the refresh token was
/// rejected or the stored session could not be used. The user must sign in
/// again.
final class SessionExpired extends AuthenticationState {
  /// Creates the expired state.
  const SessionExpired();
}

/// The signed-in user, as the app sees it.
final class AuthenticatedUser {
  /// Creates a user.
  const AuthenticatedUser({
    required this.id,
    this.email,
    this.phone,
    this.roles = const {},
    this.isAnonymous = false,
  });

  /// Stable user ID (the JWT `sub`).
  final String id;

  /// Email, when the account has one.
  final String? email;

  /// Phone number, when the account has one.
  final String? phone;

  /// Roles for client-side authorization hints. Read from
  /// server-controlled claims only (never user-editable metadata).
  final Set<Role> roles;

  /// Whether this is an anonymous sign-in.
  final bool isAnonymous;

  @override
  bool operator ==(Object other) =>
      other is AuthenticatedUser &&
      other.id == id &&
      other.email == email &&
      other.phone == phone &&
      other.isAnonymous == isAnonymous &&
      other.roles.length == roles.length &&
      other.roles.containsAll(roles);

  @override
  int get hashCode => Object.hash(
    id,
    email,
    phone,
    isAnonymous,
    Object.hashAllUnordered(roles),
  );

  /// Never includes contact details.
  @override
  String toString() => 'AuthenticatedUser($id)';
}
