import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Which router fallback is being shown.
enum RouterPlaceholderKind {
  /// Authentication is still initializing.
  pending,

  /// Sign-in is required and no sign-in location is configured.
  signInRequired,

  /// The user may not open the requested route.
  forbidden,

  /// No route matches, or a deep link was rejected.
  notFound,
}

/// Builds what a router fallback shows. Replace it (through
/// `RouterOptions.placeholderBuilder`) when the product's real waiting,
/// error and not-found screens exist.
typedef RouterPlaceholderBuilder = Widget Function(
  BuildContext context,
  RouterPlaceholderKind kind,
  GoRouterState state,
);

/// The default fallback: [RouterPlaceholder].
Widget defaultRouterPlaceholder(
  BuildContext context,
  RouterPlaceholderKind kind,
  GoRouterState state,
) => RouterPlaceholder(kind: kind);

/// Renders nothing. Not a screen: it only gives the router's fallback
/// locations something to show until product screens replace it.
final class RouterPlaceholder extends StatelessWidget {
  /// Creates the placeholder for [kind].
  const RouterPlaceholder({required this.kind, super.key});

  /// Which fallback this is.
  final RouterPlaceholderKind kind;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
