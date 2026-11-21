import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../config/env.dart';
import '../error/error_widget_builder.dart';
import '../error/global_error_handlers.dart';
import '../formatting/app_formatters.dart';
import '../theme/font_licenses.dart';
import 'app_container.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'platform_providers.dart';

/// Prepares everything the app needs before the first frame and returns the
/// root [ProviderContainer]. Knows nothing about features or screens.
///
/// Steps, in order:
/// 1. Initialize Flutter bindings.
/// 2. Read and validate the environment configuration. An invalid build
///    throws `EnvConfigException` here, before anything else starts.
/// 3. Create the Riverpod container, which wires the infrastructure.
/// 4. Route uncaught framework and platform errors to the `ErrorReporter`,
///    and keep error details out of failed widgets outside debug builds.
/// 5. Register the bundled fonts' licences.
/// 6. Initialize Supabase Auth with secure storage and restore the session.
/// 7. Load date formatting data, and start the services that follow the
///    session: per-user cleanup and push notifications.
///
/// [overrides] are added to the container; the app uses them to register
/// the features' route modules (see `lib/app_routes.dart`).
///
/// Run it inside `runGuardedZone` (see `main.dart`) so the binding and the
/// app share the zone that catches asynchronous errors.
///
Future<ProviderContainer> bootstrap({
  List<Override> overrides = const [],
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = Env.fromEnvironment();
  final container = createAppContainer(env: env, overrides: overrides);

  installGlobalErrorHandlers(container.read(errorReporterProvider));
  installErrorWidgetBuilder();
  registerFontLicenses();

  // Supabase is initialized here, once, with secure session storage; the
  // SDK restores the persisted session while initializing.
  await container.read(supabaseAuthClientProvider.future);
  await container.read(authenticationSessionProvider).restoreSession();

  await AppFormatters.initialize();
  container
    ..read(sessionCleanupProvider)
    ..read(pushNotificationCoordinatorProvider);

  return container;
}
