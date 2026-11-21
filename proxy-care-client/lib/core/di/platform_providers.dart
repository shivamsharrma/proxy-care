import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/authentication_state.dart';
import '../connectivity/connectivity_monitor.dart';
import '../lifecycle/app_lifecycle.dart';
import '../notifications/push_notifications.dart';
import '../platform/app_platform.dart';
import '../security/session_cleanup.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'router_providers.dart';

// Device-facing services: connectivity, lifecycle, platform, push
// notifications, and per-user cleanup when a session ends.

/// The connectivity source. Override in tests.
final connectivityMonitorProvider = Provider<ConnectivityMonitor>(
  (ref) => PluginConnectivityMonitor(),
);

/// The current [ConnectivityStatus]: loading until first known, then
/// updated on every change. A network connection is not proof that the API
/// is reachable (see [ConnectivityStatus]).
final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((
  ref,
) async* {
  final monitor = ref.watch(connectivityMonitorProvider);
  yield await monitor.current();
  yield* monitor.changes;
});

/// The app's lifecycle phase. Services `ref.listen` to it (for example to
/// pause work in the background) instead of observing widgets.
final appLifecyclePhaseProvider =
    NotifierProvider<AppLifecycleController, AppLifecyclePhase>(
      AppLifecycleController.new,
    );

/// Follows Flutter's [AppLifecycleListener]. Requires an initialized
/// binding.
final class AppLifecycleController extends Notifier<AppLifecyclePhase> {
  @override
  AppLifecyclePhase build() {
    final listener = AppLifecycleListener(
      onStateChange: (lifecycle) => state = phaseOf(lifecycle),
    );
    ref.onDispose(listener.dispose);
    return phaseOf(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
    );
  }
}

/// The platform of this build.
final appPlatformProvider = Provider<AppPlatform>((ref) => AppPlatform.current);

/// Tasks that clear per-user data when the session ends. Runs them when
/// the authentication state leaves `Authenticated`. Read once at start-up
/// (bootstrap) so it follows the session from the beginning.
final sessionCleanupProvider = Provider<SessionCleanup>((ref) {
  final cleanup = SessionCleanup(ref.watch(errorReporterProvider));
  ref.listen(authenticationStateProvider, (previous, next) {
    if (previous is Authenticated && next is! Authenticated) {
      unawaited(cleanup.run());
    }
  });
  return cleanup;
});

/// The push provider adapter. Unavailable until a provider is chosen
/// (backlog: push notifications); override it then.
final pushMessagingServiceProvider = Provider<PushMessagingService>(
  (ref) => const UnavailablePushMessagingService(),
);

/// Backend registration of push tokens. A no-op until the endpoint exists.
final deviceTokenRegistryProvider = Provider<DeviceTokenRegistry>(
  (ref) => const NoopDeviceTokenRegistry(),
);

/// Connects push notifications to the session and the router. Read once at
/// start-up (bootstrap).
final pushNotificationCoordinatorProvider =
    Provider<PushNotificationCoordinator>((ref) {
      final coordinator = PushNotificationCoordinator(
        messaging: ref.watch(pushMessagingServiceProvider),
        registry: ref.watch(deviceTokenRegistryProvider),
        platform: ref.watch(appPlatformProvider),
        open: (payload) =>
            ref.read(notificationNavigatorProvider).open(payload),
        reporter: ref.watch(errorReporterProvider),
      );
      ref.watch(sessionCleanupProvider).register('push', coordinator.signedOut);
      ref.listen(authenticationStateProvider, (previous, next) {
        if (next is Authenticated && previous is! Authenticated) {
          unawaited(coordinator.signedIn());
        }
      }, fireImmediately: true);
      unawaited(coordinator.start());
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });
