import '../auth/authentication_state.dart';
import '../auth/authorization/authorization.dart';
import 'deep_link_policy.dart';
import 'intended_destination.dart';
import 'redirect_destinations.dart';
import 'route_access.dart';
import 'route_conventions.dart';

// Route guards. Pure Dart: they see a snapshot of the navigation and of the
// authentication state and return where to go instead, or null to allow.
// No I/O, no navigation calls, no side effects; they run on every
// navigation and whenever the authentication state changes.

/// What a guard decides about.
final class RouteRequest {
  /// Creates a request.
  const RouteRequest({
    required this.uri,
    required this.matchedLocation,
    required this.access,
    required this.authentication,
    this.isUnmatched = false,
  });

  /// The full requested URI (a deep link may include scheme and host).
  final Uri uri;

  /// The matched path, without query.
  final String matchedLocation;

  /// The matched route's access, or null when none was declared.
  final RouteAccess? access;

  /// The authentication state at the time of the request.
  final AuthenticationState authentication;

  /// Whether no route matched (the router shows its not-found page).
  final bool isUnmatched;

  /// The requested in-app location (path and query).
  String get location => IntendedDestination.locationOf(uri);
}

/// One redirect rule.
abstract interface class RouteGuard {
  /// The location to go to instead of [request], or null to allow it.
  String? redirect(RouteRequest request);
}

/// Runs [guards] in order; the first redirect wins.
///
/// A redirect to the requested URI itself is treated as "allow", so a
/// misconfigured destination cannot loop. (A full deep link redirected to
/// its own path is a real redirect: it drops scheme and host.)
final class RedirectPipeline {
  /// Creates a pipeline.
  const RedirectPipeline(this.guards);

  /// The guards, in order.
  final List<RouteGuard> guards;

  /// The location to go to instead of [request], or null to allow it.
  String? redirect(RouteRequest request) {
    for (final guard in guards) {
      final target = guard.redirect(request);
      if (target != null && target != request.uri.toString()) return target;
    }
    return null;
  }
}

/// Turns full deep-link URLs into in-app locations, and sends links the app
/// must not open to the not-found location.
final class DeepLinkGuard implements RouteGuard {
  /// Creates the guard.
  const DeepLinkGuard({required this.policy, required this.destinations});

  /// Which links are accepted.
  final DeepLinkPolicy policy;

  /// Fallback locations.
  final RedirectDestinations destinations;

  @override
  String? redirect(RouteRequest request) {
    final uri = request.uri;
    if (!uri.hasScheme && !uri.hasAuthority) return null;
    return policy.resolve(uri) ?? destinations.notFoundLocation;
  }
}

/// Enforces [RouteAccess] against the authentication state and preserves
/// the interrupted location.
///
/// - Public routes: always allowed.
/// - Authenticated routes: signed-out users go to the sign-in location,
///   expired sessions to the session-expired location (with
///   `reason=sessionExpired`), and while authentication initializes users
///   wait on the pending location. Each redirect carries `from=<location>`.
/// - Guest-only routes and the pending location: once the state allows it,
///   users continue to `from` (if safe) or the home location.
final class AuthenticationGuard implements RouteGuard {
  /// Creates the guard.
  const AuthenticationGuard(this.destinations);

  /// Where to send users.
  final RedirectDestinations destinations;

  @override
  String? redirect(RouteRequest request) {
    if (request.isUnmatched) return null;
    final auth = request.authentication;

    if (request.matchedLocation == _pathOf(destinations.pendingLocation)) {
      return auth is AuthenticationInitializing ? null : _resume(request);
    }

    switch (request.access ?? const AuthenticatedAccess()) {
      case PublicAccess():
        return null;
      case GuestOnlyAccess():
        return auth is Authenticated ? _resume(request) : null;
      case AuthenticatedAccess():
        return switch (auth) {
          Authenticated() => null,
          AuthenticationInitializing() => _interrupt(
            request,
            destinations.pendingLocation,
          ),
          Unauthenticated() => _interrupt(request, destinations.signInLocation),
          SessionExpired() => _interrupt(
            request,
            destinations.sessionExpiredLocation,
            reason: RouterRedirectReason.sessionExpired,
          ),
        };
    }
  }

  String? _interrupt(RouteRequest request, String target, {String? reason}) {
    if (_pathOf(target) == request.matchedLocation) return null;
    return IntendedDestination.attach(
      target,
      intended: request.location,
      reason: reason,
    );
  }

  String? _resume(RouteRequest request) {
    final here = request.matchedLocation;
    final intended = IntendedDestination.of(request.uri);
    if (intended != null && _pathOf(intended) != here) return intended;
    final home = destinations.home;
    if (home != null && _pathOf(home) != here) return home;
    return null;
  }
}

/// Why a signed-in user may not open a route.
enum RouteDenial {
  /// The user has none of the required roles.
  missingRole,

  /// The user lacks a required permission.
  missingPermission,

  /// The route's feature is not available to the user.
  featureUnavailable,
}

/// Decides whether a feature is available to a user (feature flags, plans,
/// rollouts). Pure Dart.
abstract interface class FeatureAccessPolicy {
  /// Whether [feature] is available to [user].
  bool allows(String feature, AuthenticatedUser user);
}

/// Features are available when their flag is in [enabledFlags] (for
/// example the `FEATURE_FLAGS` build setting).
final class FeatureFlagAccessPolicy implements FeatureAccessPolicy {
  /// Creates the policy.
  const FeatureFlagAccessPolicy(this.enabledFlags);

  /// Enabled feature flags.
  final Set<String> enabledFlags;

  @override
  bool allows(String feature, AuthenticatedUser user) =>
      enabledFlags.contains(feature);
}

/// Evaluates [AuthenticatedAccess] restrictions for a user. Independent of
/// widgets and of the router, so the same decision can later hide a menu
/// entry for a route the user may not open.
final class RouteAuthorizer {
  /// Creates the authorizer.
  const RouteAuthorizer({required this.authorization, required this.features});

  /// Role → permission rules.
  final AuthorizationService authorization;

  /// Feature availability.
  final FeatureAccessPolicy features;

  /// Why [user] may not open a route with [access], or null if they may.
  RouteDenial? check(AuthenticatedAccess access, AuthenticatedUser user) {
    if (access.anyOfRoles.isNotEmpty &&
        !access.anyOfRoles.any(user.roles.contains)) {
      return RouteDenial.missingRole;
    }
    for (final permission in access.permissions) {
      if (!authorization.decide(user.roles, permission).isAllowed) {
        return RouteDenial.missingPermission;
      }
    }
    final feature = access.feature;
    if (feature != null && !features.allows(feature, user)) {
      return RouteDenial.featureUnavailable;
    }
    return null;
  }
}

/// Sends signed-in users who may not open a route to the forbidden
/// location. Signed-out users are left to [AuthenticationGuard].
final class AuthorizationGuard implements RouteGuard {
  /// Creates the guard.
  const AuthorizationGuard({
    required this.authorizer,
    required this.destinations,
  });

  /// The access rules.
  final RouteAuthorizer authorizer;

  /// Where to send denied users.
  final RedirectDestinations destinations;

  @override
  String? redirect(RouteRequest request) {
    if (request.isUnmatched) return null;
    final access = request.access ?? const AuthenticatedAccess();
    final auth = request.authentication;
    if (access is! AuthenticatedAccess || auth is! Authenticated) return null;
    if (authorizer.check(access, auth.user) == null) return null;
    final target = destinations.forbiddenLocation;
    return _pathOf(target) == request.matchedLocation ? null : target;
  }
}

String _pathOf(String location) => Uri.parse(location).path;
