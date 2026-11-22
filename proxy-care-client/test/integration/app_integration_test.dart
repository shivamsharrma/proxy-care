import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:proxy_care_client/app.dart';
import 'package:proxy_care_client/core/auth/authentication_state.dart';
import 'package:proxy_care_client/core/config/app_environment.dart';
import 'package:proxy_care_client/core/config/app_variant.dart';
import 'package:proxy_care_client/core/di/auth_providers.dart';
import 'package:proxy_care_client/core/di/bootstrap.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';
import 'package:proxy_care_client/core/di/network_providers.dart';
import 'package:proxy_care_client/core/di/platform_providers.dart';
import 'package:proxy_care_client/core/di/router_providers.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/network/api_client.dart';
import 'package:proxy_care_client/core/network/dio_factory.dart';
import 'package:proxy_care_client/core/router/deep_link_policy.dart';
import 'package:proxy_care_client/core/router/redirect_destinations.dart';
import 'package:proxy_care_client/core/router/router_options.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/matchers.dart';
import '../helpers/router_harness.dart';
import '../mocks/core_mocks.dart';

// Integration tests: the real bootstrap, container, router, networking stack
// and root widget together. Only the edges are replaced: the authentication
// session (fake), the HTTP adapter (no network) and the route modules
// (test-only routes; the app has no product screens yet).

const _options = RouterOptions(
  initialLocation: '/public',
  destinations: RedirectDestinations(signIn: '/guest', home: '/home'),
  deepLinks: DeepLinkPolicy(allowedHosts: {'links.example.test'}),
  placeholderBuilder: labelledPlaceholder,
);

final class _App {
  _App(this.container, this.session, this.http);

  final ProviderContainer container;
  final FakeAuthenticationSession session;
  final FakeHttpAdapter http;

  GoRouter get router => container.read(routerProvider);
  Uri get uri => router.routerDelegate.currentConfiguration.uri;

  Future<void> emit(WidgetTester tester, AuthenticationState state) async {
    session.emit(state);
    await tester.pumpAndSettle();
  }
}

/// Bootstraps the app as `main` does, with mocked backend edges, and pumps
/// the root widget. Restores the global error handlers bootstrap installs.
Future<_App> _launch(
  WidgetTester tester, {
  AuthenticationState auth = const Unauthenticated(),
  String? token,
  String? tokenAfterRefresh,
}) async {
  final flutterHandler = FlutterError.onError;
  final platformHandler = PlatformDispatcher.instance.onError;
  addTearDown(() {
    FlutterError.onError = flutterHandler;
    PlatformDispatcher.instance.onError = platformHandler;
  });

  final session = FakeAuthenticationSession(
    token: token,
    tokenAfterRefresh: tokenAfterRefresh,
  )..currentState = auth;
  final http = FakeHttpAdapter()..fallback = respondJson(dataBody(null));
  final container = await bootstrap(
    variant: AppVariant.user,
    overrides: [
      authenticationSessionProvider.overrideWithValue(session),
      routeModulesProvider.overrideWithValue([TestRouteModule()]),
      routerOptionsProvider.overrideWithValue(_options),
      loggerProvider.overrideWithValue(RecordingLogger()),
      dioProvider.overrideWith(
        (ref) => DioFactory(
          baseUrl: ref.watch(envProvider).apiBaseUrl,
          tokens: ref.watch(authenticationSessionProvider),
          recovery: ref.watch(sessionTokenRecoveryProvider),
          log: (_) {},
          adapter: http,
          retryDelay: (_) async {},
        ).create(),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ProxyCareApp(),
    ),
  );
  await tester.pumpAndSettle();

  // The test framework checks the error handler is unchanged at the end of
  // the body, before tear-downs run.
  FlutterError.onError = flutterHandler;
  return _App(container, session, http);
}

void main() {
  testWidgets('bootstrap initializes dependencies and the router', (
    tester,
  ) async {
    final app = await _launch(tester);

    expect(
      app.container.read(envProvider).environment,
      AppEnvironment.development,
    );
    expect(app.container.read(appFormattersProvider).rupees(109900), '₹1,099');
    expect(
      app.container.read(authenticationStateProvider),
      isA<Unauthenticated>(),
    );
    expect(app.uri.toString(), '/public');
    expect(find.text('public'), findsOneWidget);
  });

  testWidgets('a cold-start deep link waits for sign-in, then opens', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue =
        'https://links.example.test/items/9';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    final app = await _launch(tester);
    expect(app.uri.path, '/guest');
    expect(app.uri.queryParameters['from'], '/items/9');

    await app.emit(tester, signedIn());
    expect(app.uri.toString(), '/items/9');
    expect(find.text('item 9 tab - extra -'), findsOneWidget);
  });

  testWidgets('a deep link while running is guarded like navigation', (
    tester,
  ) async {
    final app = await _launch(tester, auth: signedIn());

    await deliverPlatformLink(tester, 'https://links.example.test/admin');
    expect(app.uri.path, RouterLocations.forbidden);

    await deliverPlatformLink(tester, 'https://links.example.test/items/12');
    expect(app.uri.toString(), '/items/12');
  });

  testWidgets('session lifecycle: token, refresh, expiry and cleanup', (
    tester,
  ) async {
    final app = await _launch(
      tester,
      auth: signedIn(),
      token: 'old',
      tokenAfterRefresh: 'new',
    );
    var cleanups = 0;
    app.container
        .read(sessionCleanupProvider)
        .register('test', () async => cleanups++);
    app.router.go('/home');
    await tester.pumpAndSettle();

    // The API sees the token; a 401 is recovered by one refresh and replay.
    app.http.enqueue([
      respondProblem('UNAUTHENTICATED', status: 401),
    ]);
    await tester.runAsync(
      () =>
          app.container.read(apiClientProvider).get('/me', decode: ignoreBody),
    );
    expect(app.http.requests.map((r) => r.headers['Authorization']), [
      'Bearer old',
      'Bearer new',
    ]);
    expect(app.session.refreshes, 1);

    // The session expires: the protected route is left and per-user data
    // is cleaned up.
    await app.emit(tester, const SessionExpired());
    expect(app.uri.path, '/guest');
    expect(app.uri.queryParameters, {
      'from': '/home',
      'reason': 'sessionExpired',
    });
    expect(cleanups, 1);

    // Signed out, protected requests carry no token and fail as such.
    app.session.token = null;
    app.http.enqueue([
      respondProblem('UNAUTHENTICATED', status: 401),
    ]);
    await tester.runAsync(
      () => expectLater(
        app.container.read(apiClientProvider).get('/me', decode: ignoreBody),
        throwsAppException<UnauthorizedException>(),
      ),
    );
    expect(
      app.http.requests.last.headers.containsKey('Authorization'),
      isFalse,
    );
  });
}
