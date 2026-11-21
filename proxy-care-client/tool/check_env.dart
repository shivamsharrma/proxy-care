import 'dart:convert';
import 'dart:io';

import 'package:proxy_care_client/core/config/env.dart';
import 'package:proxy_care_client/core/config/env_exception.dart';

/// Validates a `--dart-define-from-file` JSON file against the [Env] rules.
///
/// Usage: `dart run tool/check_env.dart config/env/production.json`
///
/// Exits with a non-zero code when the file is missing or invalid, so a build
/// can stop before producing an artifact with the wrong configuration.
void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/check_env.dart <defines-file.json>');
    exitCode = 64;
    return;
  }

  final file = File(arguments.single);
  if (!file.existsSync()) {
    stderr.writeln('Defines file not found: ${file.path}');
    exitCode = 66;
    return;
  }

  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    stderr.writeln('${file.path} must contain a JSON object.');
    exitCode = 65;
    return;
  }

  String read(String key) => decoded[key]?.toString() ?? '';

  try {
    final env = Env.parse(
      appEnv: read(Env.appEnvKey),
      apiBaseUrl: read(Env.apiBaseUrlKey),
      appName: read(Env.appNameKey),
      enableLogging: read(Env.enableLoggingKey),
      featureFlags: read(Env.featureFlagsKey),
      supabaseUrl: read(Env.supabaseUrlKey),
      supabasePublishableKey: read(Env.supabasePublishableKeyKey),
      // Files are used for real builds, so they must name the environment.
      requireExplicitEnvironment: true,
    );
    stdout.writeln('${file.path} is valid: $env');
  } on EnvConfigException catch (error) {
    stderr.writeln('${file.path}: $error');
    exitCode = 1;
  }
}
