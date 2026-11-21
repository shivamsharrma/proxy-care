import '../auth/authorization/authorization.dart';

/// Who may open a route. Pure Dart.
///
/// A route declares its access in its metadata (see [asMetadata] and
/// `RouteDefinition`); child routes inherit the nearest ancestor's access
/// and may override it. The registry rejects a route tree in which a route
/// has no access at all, and the guards treat a missing value as
/// [AuthenticatedAccess], so the default is never "public".
sealed class RouteAccess {
  const RouteAccess();

  /// Route metadata key that carries a route's [RouteAccess].
  static const metadataKey = 'proxycare.access';

  /// This access as route metadata.
  Map<String, Object> get asMetadata => {metadataKey: this};

  /// The access in a route's merged [metadata], or null when none is set.
  static RouteAccess? fromMetadata(Map<String, dynamic>? metadata) {
    final value = metadata?[metadataKey];
    return value is RouteAccess ? value : null;
  }
}

/// Anyone may open the route, signed in or not.
final class PublicAccess extends RouteAccess {
  /// Creates public access.
  const PublicAccess();
}

/// Only signed-out users may open the route (for example a future sign-in
/// route). A signed-in user is sent on to the intended destination or the
/// configured home location.
final class GuestOnlyAccess extends RouteAccess {
  /// Creates guest-only access.
  const GuestOnlyAccess();
}

/// Only signed-in users may open the route, optionally restricted further.
///
/// All restrictions must hold: the user needs at least one of [anyOfRoles]
/// (when not empty), every one of [permissions], and [feature] (when set)
/// must be available to them. These checks only decide what the app shows;
/// the API enforces access to data.
final class AuthenticatedAccess extends RouteAccess {
  /// Creates authenticated access with optional restrictions.
  const AuthenticatedAccess({
    this.anyOfRoles = const {},
    this.permissions = const {},
    this.feature,
  });

  /// Roles of which the user needs at least one; empty means any role.
  final Set<Role> anyOfRoles;

  /// Permissions the user needs, all of them.
  final Set<Permission> permissions;

  /// A feature that must be available to the user (see
  /// `FeatureAccessPolicy`), or null.
  final String? feature;
}
