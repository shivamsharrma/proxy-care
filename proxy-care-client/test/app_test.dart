import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/app.dart';
import 'package:proxy_care_client/core/auth/authentication_session.dart';
import 'package:proxy_care_client/core/di/auth_providers.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';
import 'package:proxy_care_client/core/router/router_placeholder.dart';

import 'fixtures/env_fixtures.dart';

void main() {
  testWidgets('ProxyCareApp uses the configured app name', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          envProvider.overrideWithValue(testEnv(appName: 'Proxy Care Test')),
          authenticationSessionProvider.overrideWithValue(
            const UnconfiguredAuthenticationSession(),
          ),
        ],
        child: const ProxyCareApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Proxy Care Test');
    expect(tester.takeException(), isNull);
  });

  testWidgets('routes through the router; no screen is registered', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          envProvider.overrideWithValue(testEnv()),
          authenticationSessionProvider.overrideWithValue(
            const UnconfiguredAuthenticationSession(),
          ),
        ],
        child: const ProxyCareApp(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.routerConfig, isNotNull);
    final placeholder = tester.widget<RouterPlaceholder>(
      find.byType(RouterPlaceholder),
    );
    expect(placeholder.kind, RouterPlaceholderKind.notFound);
  });
}
