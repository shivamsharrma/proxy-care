import 'intended_destination.dart';

/// Which incoming links the app opens, and where. Pure Dart.
///
/// Android App Links and iOS Universal Links arrive as full `https` URLs;
/// links typed or followed on web, and links built inside the app, arrive
/// as paths. Both are turned into an in-app location (path and query) by
/// [resolve]. No domain is configured yet: production domains are added to
/// [allowedHosts] once the domain is owned and verified (see
/// docs/deep-linking.md).
final class DeepLinkPolicy {
  /// Creates a policy accepting https links on [allowedHosts] (lowercase
  /// host names, no port).
  const DeepLinkPolicy({this.allowedHosts = const {}});

  /// Hosts whose links the app opens, for example `<APP_LINK_DOMAIN>`.
  final Set<String> allowedHosts;

  /// The in-app location for [uri], or null when the app must not open it
  /// (unknown host or scheme, user info, or an unsafe path).
  String? resolve(Uri uri) {
    if (!uri.hasScheme && !uri.hasAuthority) {
      return IntendedDestination.sanitize(IntendedDestination.locationOf(uri));
    }
    // App Links and Universal Links are always https.
    if (uri.scheme.toLowerCase() != 'https') return null;
    if (!allowedHosts.contains(uri.host.toLowerCase())) return null;
    if (uri.userInfo.isNotEmpty) return null;
    return IntendedDestination.sanitize(IntendedDestination.locationOf(uri));
  }
}
