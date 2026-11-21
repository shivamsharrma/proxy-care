import 'dart:convert';

import 'app_environment.dart';
import 'env_exception.dart';

/// Immutable, validated application configuration supplied at compile time.
///
/// Values come from `--dart-define` or `--dart-define-from-file` and are read
/// with [String.fromEnvironment]. Call [Env.fromEnvironment] once at start-up;
/// call [Env.parse] directly from tests and tooling.
///
/// This file depends only on `dart:core`, so command-line tools can validate a
/// configuration file without the Flutter SDK.
final class Env {
  const Env._({
    required this.environment,
    required this.apiBaseUrl,
    required this.appName,
    required this.enableLogging,
    required this.featureFlags,
    this.supabaseUrl,
    this.supabasePublishableKey,
  });

  /// Reads the compile-time defines and validates them.
  ///
  /// Throws an [EnvConfigException] listing every invalid value.
  factory Env.fromEnvironment() {
    return Env.parse(
      appEnv: const String.fromEnvironment(appEnvKey),
      apiBaseUrl: const String.fromEnvironment(apiBaseUrlKey),
      appName: const String.fromEnvironment(appNameKey),
      enableLogging: const String.fromEnvironment(enableLoggingKey),
      featureFlags: const String.fromEnvironment(featureFlagsKey),
      supabaseUrl: const String.fromEnvironment(supabaseUrlKey),
      supabasePublishableKey: const String.fromEnvironment(
        supabasePublishableKeyKey,
      ),
      requireExplicitEnvironment: isReleaseBuild,
    );
  }

  /// Whether this is a release (product) build. Release builds must name
  /// their environment, so they never fall back to development.
  static const bool isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  /// Name of the define that selects the environment.
  static const appEnvKey = 'APP_ENV';

  /// Name of the define that holds the API base URL.
  static const apiBaseUrlKey = 'API_BASE_URL';

  /// Name of the define that holds the display name.
  static const appNameKey = 'APP_NAME';

  /// Name of the define that switches logging on or off.
  static const enableLoggingKey = 'ENABLE_LOGGING';

  /// Name of the define that lists enabled feature flags.
  static const featureFlagsKey = 'FEATURE_FLAGS';

  /// Name of the define that holds the Supabase project URL.
  static const supabaseUrlKey = 'SUPABASE_URL';

  /// Name of the define that holds the Supabase publishable key.
  static const supabasePublishableKeyKey = 'SUPABASE_PUBLISHABLE_KEY';

  /// API base URL used only when the environment is development and
  /// `API_BASE_URL` is not supplied. Staging and production never fall back.
  static final Uri developmentApiBaseUrl = Uri.parse('http://localhost:8080');

  /// Display name used when `APP_NAME` is not supplied.
  static const defaultAppName = 'Proxy Care';

  /// A valid feature flag name: snake_case.
  static final RegExp featureFlagPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  static final RegExp _trailingSlashes = RegExp(r'/+$');

  static const Set<String> _loopbackHosts = {
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '::1',
    '10.0.2.2',
  };

  /// The environment this build targets.
  final AppEnvironment environment;

  /// Base URL for API requests, without a trailing slash.
  final Uri apiBaseUrl;

  /// Display name of the application.
  final String appName;

  /// Whether application logging is enabled.
  final bool enableLogging;

  /// Names of the feature flags switched on for this build. Unmodifiable.
  final Set<String> featureFlags;

  /// Supabase project URL (Auth), without a trailing slash; null when
  /// authentication is not configured (development only).
  final Uri? supabaseUrl;

  /// Supabase publishable key (`sb_publishable_…`, or a legacy anon key).
  /// Safe to ship in the app; never a secret or service-role key.
  final String? supabasePublishableKey;

  /// Whether Supabase Auth is configured.
  bool get isAuthConfigured =>
      supabaseUrl != null && supabasePublishableKey != null;

  /// Whether this is a production build.
  bool get isProduction => environment == AppEnvironment.production;

  /// Whether the feature flag [name] is switched on.
  bool isFeatureEnabled(String name) => featureFlags.contains(name);

  /// Validates raw define values and builds an [Env].
  ///
  /// An empty string means the define was not supplied. Every value is
  /// checked before throwing, so one failed build reports every problem.
  ///
  /// Rules:
  /// * `APP_ENV`: `development`, `staging` or `production` (any case).
  ///   Defaults to `development` only when [requireExplicitEnvironment] is
  ///   false (debug builds and tests); release builds and `tool/check_env`
  ///   require it, so a production build can never silently become a
  ///   development one.
  /// * `API_BASE_URL`: absolute http(s) URL without query or fragment.
  ///   Required, and must use https, in staging and production; production
  ///   must not point to a local host. Defaults to [developmentApiBaseUrl]
  ///   only in development.
  /// * `APP_NAME`: defaults to [defaultAppName].
  /// * `ENABLE_LOGGING`: `true` or `false`; defaults to `false` in
  ///   production and `true` elsewhere.
  /// * `FEATURE_FLAGS`: comma-separated snake_case names; defaults to none.
  /// * `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`: both or neither.
  ///   Required in staging and production, where the URL must use https;
  ///   optional in development (the app then runs signed out). The key must
  ///   be a publishable (or legacy anon) key: secret (`sb_secret_…`) and
  ///   service-role keys are rejected, because they bypass Row Level
  ///   Security and must never ship in an app.
  static Env parse({
    required String appEnv,
    required String apiBaseUrl,
    required String appName,
    required String enableLogging,
    required String featureFlags,
    String supabaseUrl = '',
    String supabasePublishableKey = '',
    bool requireExplicitEnvironment = false,
  }) {
    final errors = <String>[];

    final environment = _parseEnvironment(
      appEnv,
      errors,
      required: requireExplicitEnvironment,
    );
    // An unknown APP_ENV is checked against the strictest (production) rules
    // so that no other problem is hidden behind it.
    final rules = environment ?? AppEnvironment.production;
    final baseUrl = _parseApiBaseUrl(apiBaseUrl, rules, errors);
    final logging = _parseLogging(enableLogging, rules, errors);
    final flags = _parseFeatureFlags(featureFlags, errors);
    final (supabase, supabaseKey) = _parseSupabase(
      supabaseUrl,
      supabasePublishableKey,
      rules,
      errors,
    );

    if (errors.isNotEmpty) {
      throw EnvConfigException(List.unmodifiable(errors));
    }

    // Every null result above records an error, so none are null here.
    return Env._(
      environment: environment!,
      apiBaseUrl: baseUrl!,
      appName: _parseAppName(appName),
      enableLogging: logging!,
      featureFlags: flags,
      supabaseUrl: supabase,
      supabasePublishableKey: supabaseKey,
    );
  }

  static AppEnvironment? _parseEnvironment(
    String raw,
    List<String> errors, {
    required bool required,
  }) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) {
      if (required) {
        errors.add('$appEnvKey is required in release builds.');
        return null;
      }
      return AppEnvironment.development;
    }
    final environment = AppEnvironment.values.asNameMap()[value];
    if (environment == null) {
      final allowed = AppEnvironment.values.map((e) => e.name).join(', ');
      errors.add('$appEnvKey must be one of $allowed; got "$raw".');
    }
    return environment;
  }

  static Uri? _parseApiBaseUrl(
    String raw,
    AppEnvironment environment,
    List<String> errors,
  ) {
    final value = raw.trim();
    if (value.isEmpty) {
      if (environment == AppEnvironment.development) {
        return developmentApiBaseUrl;
      }
      errors.add(
        '$apiBaseUrlKey is required when $appEnvKey is ${environment.name}.',
      );
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      errors.add('$apiBaseUrlKey must be an absolute URL; got "$value".');
      return null;
    }
    if (!uri.isScheme('http') && !uri.isScheme('https')) {
      errors.add('$apiBaseUrlKey must use http or https; got "$value".');
      return null;
    }
    if (uri.hasQuery || uri.hasFragment) {
      errors.add('$apiBaseUrlKey must not contain a query or fragment.');
      return null;
    }
    if (environment != AppEnvironment.development) {
      if (!uri.isScheme('https')) {
        errors.add('$apiBaseUrlKey must use https in ${environment.name}.');
        return null;
      }
      if (environment == AppEnvironment.production &&
          _loopbackHosts.contains(uri.host)) {
        errors.add(
          '$apiBaseUrlKey must not point to ${uri.host} in production.',
        );
        return null;
      }
    }
    return uri.replace(path: uri.path.replaceFirst(_trailingSlashes, ''));
  }

  static String _parseAppName(String raw) {
    final value = raw.trim();
    return value.isEmpty ? defaultAppName : value;
  }

  static bool? _parseLogging(
    String raw,
    AppEnvironment environment,
    List<String> errors,
  ) {
    switch (raw.trim().toLowerCase()) {
      case '':
        return environment != AppEnvironment.production;
      case 'true':
        return true;
      case 'false':
        return false;
    }
    errors.add('$enableLoggingKey must be "true" or "false"; got "$raw".');
    return null;
  }

  static Set<String> _parseFeatureFlags(String raw, List<String> errors) {
    final flags = <String>{};
    for (final entry in raw.split(',')) {
      final flag = entry.trim();
      if (flag.isEmpty) {
        continue;
      }
      if (featureFlagPattern.hasMatch(flag)) {
        flags.add(flag);
      } else {
        errors.add(
          '$featureFlagsKey entry "$flag" must be snake_case (a-z, 0-9, _).',
        );
      }
    }
    return Set.unmodifiable(flags);
  }

  static (Uri?, String?) _parseSupabase(
    String rawUrl,
    String rawKey,
    AppEnvironment environment,
    List<String> errors,
  ) {
    final urlText = rawUrl.trim();
    final key = rawKey.trim();
    final isDevelopment = environment == AppEnvironment.development;

    if (urlText.isEmpty && key.isEmpty) {
      if (!isDevelopment) {
        errors.add(
          '$supabaseUrlKey and $supabasePublishableKeyKey are required when '
          '$appEnvKey is ${environment.name}.',
        );
      }
      return (null, null);
    }
    if (urlText.isEmpty || key.isEmpty) {
      errors.add(
        'Set both $supabaseUrlKey and $supabasePublishableKeyKey, or neither.',
      );
      return (null, null);
    }

    final url = Uri.tryParse(urlText);
    final validUrl =
        url != null &&
        url.hasScheme &&
        url.host.isNotEmpty &&
        (url.scheme == 'https' || (isDevelopment && url.scheme == 'http')) &&
        !url.hasQuery &&
        !url.hasFragment;
    if (!validUrl) {
      errors.add(
        isDevelopment
            ? '$supabaseUrlKey must be an http(s) URL without query or '
                  'fragment.'
            : '$supabaseUrlKey must be an https URL without query or '
                  'fragment.',
      );
    }

    if (_isSecretKey(key)) {
      errors.add(
        '$supabasePublishableKeyKey must be a publishable key; secret and '
        'service-role keys must never be included in the app.',
      );
    }

    if (!validUrl || _isSecretKey(key)) return (null, null);
    return (url.replace(path: url.path.replaceAll(_trailingSlashes, '')), key);
  }

  /// Whether [key] is a Supabase secret key or a legacy service-role JWT.
  static bool _isSecretKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final Object? claims = jsonDecode(payload);
      return claims is Map<String, Object?> && claims['role'] == 'service_role';
    } on FormatException {
      return false;
    }
  }

  @override
  bool operator ==(Object other) {
    return other is Env &&
        other.environment == environment &&
        other.apiBaseUrl == apiBaseUrl &&
        other.appName == appName &&
        other.enableLogging == enableLogging &&
        other.featureFlags.length == featureFlags.length &&
        other.featureFlags.containsAll(featureFlags) &&
        other.supabaseUrl == supabaseUrl &&
        other.supabasePublishableKey == supabasePublishableKey;
  }

  @override
  int get hashCode {
    return Object.hash(
      environment,
      apiBaseUrl,
      appName,
      enableLogging,
      Object.hashAllUnordered(featureFlags),
      supabaseUrl,
      supabasePublishableKey,
    );
  }

  @override
  String toString() {
    return 'Env(environment: ${environment.name}, apiBaseUrl: $apiBaseUrl, '
        'appName: $appName, enableLogging: $enableLogging, '
        'featureFlags: $featureFlags, supabaseUrl: $supabaseUrl)';
  }
}
