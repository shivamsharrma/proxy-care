import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_routes.dart';
import 'core/config/app_variant.dart';
import 'core/di/bootstrap.dart';
import 'core/di/core_providers.dart';
import 'core/di/router_providers.dart';
import 'core/error/error_reporter.dart';
import 'core/error/global_error_handlers.dart';

void main() {
  ErrorReporter? reporter;
  runGuardedZone(
    () async {
      // A build without a valid APP_VARIANT throws EnvConfigException here.
      final variant = AppVariant.fromEnvironment();
      final container = await bootstrap(
        variant: variant,
        overrides: [
          routeModulesProvider.overrideWith(
            (ref) => routeModulesFor(
              ref.watch(appVariantProvider),
              ref.watch(envProvider),
            ),
          ),
        ],
      );
      reporter = container.read(errorReporterProvider);
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const ProxyCareApp(),
        ),
      );
    },
    reporter: () => reporter,
  );
}
