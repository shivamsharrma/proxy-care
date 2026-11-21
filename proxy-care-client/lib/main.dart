import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_routes.dart';
import 'core/di/bootstrap.dart';
import 'core/di/core_providers.dart';
import 'core/di/router_providers.dart';
import 'core/error/error_reporter.dart';
import 'core/error/global_error_handlers.dart';

void main() {
  ErrorReporter? reporter;
  runGuardedZone(
    () async {
      final container = await bootstrap(
        overrides: [
          routeModulesProvider.overrideWith(
            (ref) => enabledRouteModules(ref.watch(envProvider)),
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
