import 'dart:async';

import '../error/error_reporter.dart';
import '../platform/app_platform.dart';

/// Whether the user lets the app show notifications.
enum PushPermission {
  /// Not asked yet.
  notDetermined,

  /// Allowed.
  granted,

  /// Refused (the user must change it in system settings).
  denied,

  /// No push provider on this platform or build.
  unsupported,
}

/// A push provider (for example Firebase Cloud Messaging, once chosen).
/// Only an adapter implements it; nothing else imports a provider SDK.
abstract interface class PushMessagingService {
  /// The current permission, without asking.
  Future<PushPermission> permission();

  /// Asks the user (shows the system prompt where needed).
  Future<PushPermission> requestPermission();

  /// This device's push token, or null when unavailable.
  Future<String?> token();

  /// Deletes this device's token, so no more pushes arrive for it.
  Future<void> deleteToken();

  /// New tokens issued by the provider.
  Stream<String> get tokenRefreshes;

  /// The payload of the notification that launched the app (cold start),
  /// if any.
  Future<Map<String, Object?>?> initialPayload();

  /// Payloads of notifications the user taps while the app runs.
  Stream<Map<String, Object?>> get openedPayloads;
}

/// Sends this device's push token to the backend. The endpoint is not
/// defined yet (see `device_tokens` in the entity design).
abstract interface class DeviceTokenRegistry {
  /// Stores [token] for the signed-in user on [platform].
  Future<void> register(String token, AppPlatform platform);

  /// Removes [token]. Must work without a user session (the session may
  /// already have ended): the token itself identifies the row.
  Future<void> unregister(String token);
}

/// No push provider: permission is [PushPermission.unsupported] and
/// nothing is ever delivered.
final class UnavailablePushMessagingService implements PushMessagingService {
  /// Creates the unavailable service.
  const UnavailablePushMessagingService();

  @override
  Future<PushPermission> permission() async => PushPermission.unsupported;

  @override
  Future<PushPermission> requestPermission() async =>
      PushPermission.unsupported;

  @override
  Future<String?> token() async => null;

  @override
  Future<void> deleteToken() async {}

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Future<Map<String, Object?>?> initialPayload() async => null;

  @override
  Stream<Map<String, Object?>> get openedPayloads => const Stream.empty();
}

/// Registers nothing (no endpoint yet).
final class NoopDeviceTokenRegistry implements DeviceTokenRegistry {
  /// Creates the no-op registry.
  const NoopDeviceTokenRegistry();

  @override
  Future<void> register(String token, AppPlatform platform) async {}

  @override
  Future<void> unregister(String token) async {}
}

/// Connects a [PushMessagingService] to the backend and the router:
///
/// - signed in: registers the token, and every refreshed token;
/// - signed out or expired: deletes the token locally and unregisters it,
///   so the next user of the device gets no pushes meant for this one;
/// - a tapped notification (cold start or running): hands the raw payload
///   to [open], which validates it and navigates (the router guards apply).
///
/// It never asks for permission: a feature screen does, at a moment that
/// explains why. Failures are reported, never thrown.
final class PushNotificationCoordinator {
  /// Creates the coordinator.
  PushNotificationCoordinator({
    required this.messaging,
    required this.registry,
    required this.platform,
    required this.open,
    required this.reporter,
  });

  /// The push provider.
  final PushMessagingService messaging;

  /// The backend registration.
  final DeviceTokenRegistry registry;

  /// This device's platform.
  final AppPlatform platform;

  /// Opens a raw payload (`NotificationNavigator.open`).
  final void Function(Object? payload) open;

  /// Where failures go.
  final ErrorReporter reporter;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _signedIn = false;

  /// Starts handling taps and token refreshes.
  Future<void> start() async {
    _subscriptions
      ..add(messaging.openedPayloads.listen(open))
      ..add(
        messaging.tokenRefreshes.listen((token) {
          if (_signedIn) _guard(() => registry.register(token, platform));
        }),
      );
    await _guard(() async {
      final initial = await messaging.initialPayload();
      if (initial != null) open(initial);
    });
  }

  /// Registers this device for the signed-in user.
  Future<void> signedIn() async {
    _signedIn = true;
    await _guard(() async {
      final token = await messaging.token();
      if (token != null) await registry.register(token, platform);
    });
  }

  /// Stops pushes for the previous user.
  Future<void> signedOut() async {
    _signedIn = false;
    await _guard(() async {
      final token = await messaging.token();
      await messaging.deleteToken();
      if (token != null) await registry.unregister(token);
    });
  }

  /// Stops listening.
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      reporter.report(error, stackTrace, context: 'push');
    }
  }
}
