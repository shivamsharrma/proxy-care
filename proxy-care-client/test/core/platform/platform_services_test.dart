import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/auth/authentication_state.dart';
import 'package:proxy_care_client/core/connectivity/connectivity_monitor.dart';
import 'package:proxy_care_client/core/di/app_container.dart';
import 'package:proxy_care_client/core/di/auth_providers.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';
import 'package:proxy_care_client/core/di/platform_providers.dart';
import 'package:proxy_care_client/core/lifecycle/app_lifecycle.dart';
import 'package:proxy_care_client/core/notifications/push_notifications.dart';
import 'package:proxy_care_client/core/platform/app_platform.dart';

import '../../fixtures/env_fixtures.dart';
import '../../helpers/auth_fakes.dart';
import '../../mocks/core_mocks.dart';

final class _MockConnectivity extends Mock implements Connectivity {}

final class _FakeMonitor implements ConnectivityMonitor {
  final controller = StreamController<ConnectivityStatus>();
  ConnectivityStatus now = ConnectivityStatus.offline;

  @override
  Future<ConnectivityStatus> current() async => now;

  @override
  Stream<ConnectivityStatus> get changes => controller.stream;
}

final class _FakePush implements PushMessagingService {
  String? currentToken = 'token-1';
  Map<String, Object?>? launchPayload;
  final opened = StreamController<Map<String, Object?>>.broadcast();
  final refreshes = StreamController<String>.broadcast();
  var deleted = 0;

  @override
  Future<PushPermission> permission() async => PushPermission.granted;

  @override
  Future<PushPermission> requestPermission() async => PushPermission.granted;

  @override
  Future<String?> token() async => currentToken;

  @override
  Future<void> deleteToken() async => deleted++;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Future<Map<String, Object?>?> initialPayload() async => launchPayload;

  @override
  Stream<Map<String, Object?>> get openedPayloads => opened.stream;
}

final class _RecordingRegistry implements DeviceTokenRegistry {
  final calls = <String>[];

  @override
  Future<void> register(String token, AppPlatform platform) async =>
      calls.add('register $token ${platform.name}');

  @override
  Future<void> unregister(String token) async => calls.add('unregister $token');
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('connectivity', () {
    test('maps plugin results to online and offline', () {
      expect(
        PluginConnectivityMonitor.statusOf([ConnectivityResult.wifi]),
        ConnectivityStatus.online,
      );
      expect(
        PluginConnectivityMonitor.statusOf([
          ConnectivityResult.vpn,
          ConnectivityResult.mobile,
        ]),
        ConnectivityStatus.online,
      );
      expect(
        PluginConnectivityMonitor.statusOf([ConnectivityResult.none]),
        ConnectivityStatus.offline,
      );
      expect(
        PluginConnectivityMonitor.statusOf(const []),
        ConnectivityStatus.offline,
      );
    });

    test('the plugin monitor reports the current status and changes', () async {
      final plugin = _MockConnectivity();
      when(
        () => plugin.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.mobile]);
      when(() => plugin.onConnectivityChanged).thenAnswer(
        (_) => Stream.fromIterable([
          [ConnectivityResult.none],
          [ConnectivityResult.none],
          [ConnectivityResult.wifi],
        ]),
      );
      final monitor = PluginConnectivityMonitor(connectivity: plugin);

      expect(await monitor.current(), ConnectivityStatus.online);
      expect(await monitor.changes.toList(), [
        ConnectivityStatus.offline,
        ConnectivityStatus.online,
      ]);
    });

    test('the provider starts with the current status, then follows', () async {
      final monitor = _FakeMonitor();
      final container = createAppContainer(
        env: testEnv(),
        overrides: [connectivityMonitorProvider.overrideWithValue(monitor)],
      );
      addTearDown(container.dispose);
      final seen = <ConnectivityStatus?>[];
      container.listen(
        connectivityStatusProvider,
        (_, next) => seen.add(next.value),
        fireImmediately: true,
      );

      await _settle();
      monitor.controller.add(ConnectivityStatus.online);
      await _settle();

      expect(seen, [
        null,
        ConnectivityStatus.offline,
        ConnectivityStatus.online,
      ]);
    });
  });

  group('lifecycle', () {
    test('maps every Flutter state to a phase', () {
      expect(AppLifecycleState.values.map(phaseOf), [
        AppLifecyclePhase.detached,
        AppLifecyclePhase.foreground,
        AppLifecyclePhase.inactive,
        AppLifecyclePhase.background,
        AppLifecyclePhase.background,
      ]);
    });

    testWidgets('services can follow the phase without widgets', (
      tester,
    ) async {
      final container = createAppContainer(env: testEnv());
      addTearDown(container.dispose);
      final phases = <AppLifecyclePhase>[];
      container.listen(
        appLifecyclePhaseProvider,
        (_, next) => phases.add(next),
        fireImmediately: true,
      );

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }

      expect(phases.first, AppLifecyclePhase.foreground);
      expect(phases, contains(AppLifecyclePhase.inactive));
      expect(phases, contains(AppLifecyclePhase.background));
      expect(phases.last, AppLifecyclePhase.foreground);
    });
  });

  group('push notifications', () {
    setUpAll(() => registerFallbackValue(StackTrace.empty));
    late _FakePush push;
    late _RecordingRegistry registry;
    late FakeAuthenticationSession session;
    late List<Object?> opened;

    PushNotificationCoordinator start({AuthenticationState? auth}) {
      session = FakeAuthenticationSession()
        ..currentState = auth ?? const Unauthenticated();
      final container = createAppContainer(
        env: testEnv(),
        overrides: [
          authenticationSessionProvider.overrideWithValue(session),
          pushMessagingServiceProvider.overrideWithValue(push),
          deviceTokenRegistryProvider.overrideWithValue(registry),
          appPlatformProvider.overrideWithValue(AppPlatform.android),
          loggerProvider.overrideWithValue(RecordingLogger()),
        ],
      );
      addTearDown(container.dispose);
      return container.read(pushNotificationCoordinatorProvider);
    }

    setUp(() {
      push = _FakePush();
      registry = _RecordingRegistry();
      opened = [];
    });

    test('the default provider is unavailable and inert', () async {
      const service = UnavailablePushMessagingService();
      expect(await service.permission(), PushPermission.unsupported);
      expect(await service.token(), isNull);
      expect(await service.openedPayloads.isEmpty, isTrue);
    });

    test('registers on sign-in and on token refresh while signed in', () async {
      start();
      await _settle();
      expect(registry.calls, isEmpty);

      session.emit(const Authenticated(user: AuthenticatedUser(id: 'u1')));
      await _settle();
      push.refreshes.add('token-2');
      await _settle();

      expect(registry.calls, [
        'register token-1 android',
        'register token-2 android',
      ]);
    });

    test('a restored session registers at start-up', () async {
      start(
        auth: const Authenticated(user: AuthenticatedUser(id: 'u1')),
      );
      await _settle();
      expect(registry.calls, ['register token-1 android']);
    });

    test('ending the session deletes and unregisters the token', () async {
      start(
        auth: const Authenticated(user: AuthenticatedUser(id: 'u1')),
      );
      await _settle();

      session.emit(const SessionExpired());
      await _settle();
      push.refreshes.add('token-3');
      await _settle();

      expect(push.deleted, 1);
      expect(registry.calls, [
        'register token-1 android',
        'unregister token-1',
      ]);
    });

    test('taps at launch and while running are handed to the router', () async {
      final coordinator = PushNotificationCoordinator(
        messaging: push..launchPayload = {'type': 'visits.updated'},
        registry: registry,
        platform: AppPlatform.web,
        open: opened.add,
        reporter: MockErrorReporter(),
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();
      push.opened.add({'type': 'visits.assigned'});
      await _settle();

      expect(opened, [
        {'type': 'visits.updated'},
        {'type': 'visits.assigned'},
      ]);
    });

    test('failures are reported, never thrown', () async {
      final reporter = MockErrorReporter();
      final coordinator = PushNotificationCoordinator(
        messaging: push,
        registry: _ThrowingRegistry(),
        platform: AppPlatform.web,
        open: opened.add,
        reporter: reporter,
      );

      await coordinator.signedIn();

      verify(() => reporter.report(any(), any(), context: 'push')).called(1);
    });
  });

  test('the platform is web in a web build, otherwise native', () {
    expect(AppPlatform.values, contains(AppPlatform.current));
  });
}

final class _ThrowingRegistry implements DeviceTokenRegistry {
  @override
  Future<void> register(String token, AppPlatform platform) =>
      Future.error(StateError('offline'));

  @override
  Future<void> unregister(String token) => Future.error(StateError('offline'));
}
