/// The router's own fallback locations. Pure Dart.
///
/// They exist so the guards always have somewhere safe to send the user
/// while the product screens (sign-in, home, error pages) do not exist yet.
/// Each renders the configurable router placeholder. The `_` segment is
/// reserved for them by `RouteConventions`.
abstract final class RouterLocations {
  /// Shown while the authentication state is still being determined.
  static const pending = '/_/pending';

  /// Where a signed-out user goes when no sign-in location is configured.
  static const signInRequired = '/_/sign-in-required';

  /// Where a user goes when they may not open a route.
  static const forbidden = '/_/forbidden';

  /// Where a rejected deep link goes.
  static const notFound = '/_/not-found';
}

/// Where the guards send the user. Every value is an in-app location; null
/// uses the matching [RouterLocations] fallback.
///
/// Features configure these when their screens exist (for example
/// `signIn: '/sign-in'` once the sign-in route is registered), through
/// `routerOptionsProvider`. Nothing here assumes such a screen exists.
final class RedirectDestinations {
  /// Creates the destinations; all optional.
  const RedirectDestinations({
    this.signIn,
    this.sessionExpired,
    this.home,
    this.forbidden,
    this.pending,
    this.notFound,
  });

  /// The sign-in location. Must be a `GuestOnlyAccess` or public route.
  final String? signIn;

  /// Where an expired session goes; defaults to [signIn].
  final String? sessionExpired;

  /// Where a signed-in user goes from a guest-only route when no intended
  /// destination is waiting. Null keeps them where they are.
  final String? home;

  /// Where a user without access goes.
  final String? forbidden;

  /// Shown while authentication is initializing.
  final String? pending;

  /// Where a rejected deep link goes.
  final String? notFound;

  /// The effective sign-in location.
  String get signInLocation => signIn ?? RouterLocations.signInRequired;

  /// The effective session-expired location.
  String get sessionExpiredLocation => sessionExpired ?? signInLocation;

  /// The effective forbidden location.
  String get forbiddenLocation => forbidden ?? RouterLocations.forbidden;

  /// The effective pending location.
  String get pendingLocation => pending ?? RouterLocations.pending;

  /// The effective not-found location.
  String get notFoundLocation => notFound ?? RouterLocations.notFound;

  /// Every configured (non-null) location, for validation.
  List<String> get configured => [
    ?signIn,
    ?sessionExpired,
    ?home,
    ?forbidden,
    ?pending,
    ?notFound,
  ];
}
