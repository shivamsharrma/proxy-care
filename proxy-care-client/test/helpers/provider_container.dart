import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/config/env.dart';
import 'package:proxy_care_client/core/di/app_container.dart';

import '../fixtures/env_fixtures.dart';

/// Creates a container wired exactly like the app's, using [env] (default
/// [testEnv]) and any extra [overrides]. It is disposed after the test.
ProviderContainer createTestContainer({
  Env? env,
  List<Override> overrides = const [],
}) {
  final container = createAppContainer(
    env: env ?? testEnv(),
    overrides: overrides,
  );
  addTearDown(container.dispose);
  return container;
}
