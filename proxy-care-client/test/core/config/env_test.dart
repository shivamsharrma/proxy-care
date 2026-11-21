import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/config/app_environment.dart';
import 'package:proxy_care_client/core/config/env.dart';
import 'package:proxy_care_client/core/config/env_exception.dart';

void main() {
  group('defaults', () {
    test('uses development settings when nothing is defined', () {
      final env = parse();

      expect(env.environment, AppEnvironment.development);
      expect(env.isProduction, isFalse);
      expect(env.apiBaseUrl, Env.developmentApiBaseUrl);
      expect(env.appName, Env.defaultAppName);
      expect(env.enableLogging, isTrue);
      expect(env.featureFlags, isEmpty);
    });

    test('fromEnvironment reads development defaults without defines', () {
      expect(Env.isReleaseBuild, isFalse, reason: 'tests are debug builds');
      expect(Env.fromEnvironment(), parse());
    });

    test('release builds never fall back to development', () {
      expect(
        () => parse(requireExplicitEnvironment: true),
        throwsEnvError('APP_ENV is required in release builds'),
      );
      expect(
        parse(
          appEnv: 'development',
          requireExplicitEnvironment: true,
        ).environment,
        AppEnvironment.development,
      );
    });

    test('turns logging off by default in production', () {
      final env = parse(
        appEnv: 'production',
        apiBaseUrl: 'https://api.proxycare.test',
      );

      expect(env.isProduction, isTrue);
      expect(env.enableLogging, isFalse);
    });

    test('keeps logging on by default in staging', () {
      final env = parse(
        appEnv: 'staging',
        apiBaseUrl: 'https://staging.proxycare.test',
      );

      expect(env.enableLogging, isTrue);
    });
  });

  group('APP_ENV', () {
    test('ignores case and surrounding whitespace', () {
      final env = parse(
        appEnv: '  Staging ',
        apiBaseUrl: 'https://staging.proxycare.test',
      );

      expect(env.environment, AppEnvironment.staging);
    });

    test('rejects unknown values', () {
      expect(() => parse(appEnv: 'prod'), throwsEnvError('APP_ENV'));
    });
  });

  group('API_BASE_URL', () {
    test('is required in production', () {
      expect(
        () => parse(appEnv: 'production'),
        throwsEnvError('API_BASE_URL is required'),
      );
    });

    test('is required in staging', () {
      expect(
        () => parse(appEnv: 'staging'),
        throwsEnvError('API_BASE_URL is required'),
      );
    });

    test('must use https in production', () {
      expect(
        () => parse(
          appEnv: 'production',
          apiBaseUrl: 'http://api.proxycare.test',
        ),
        throwsEnvError('must use https'),
      );
    });

    test('must use https in staging', () {
      expect(
        () => parse(
          appEnv: 'staging',
          apiBaseUrl: 'http://staging.proxycare.test',
        ),
        throwsEnvError('must use https'),
      );
    });

    test('must not point to a local host in production', () {
      expect(
        () => parse(
          appEnv: 'production',
          apiBaseUrl: 'https://localhost:8443',
        ),
        throwsEnvError('must not point to localhost'),
      );
    });

    test('rejects a URL without a scheme', () {
      expect(
        () => parse(apiBaseUrl: 'api.proxycare.test'),
        throwsEnvError('must be an absolute URL'),
      );
    });

    test('rejects schemes other than http and https', () {
      expect(
        () => parse(apiBaseUrl: 'ftp://files.proxycare.test'),
        throwsEnvError('must use http or https'),
      );
    });

    test('rejects a query string', () {
      expect(
        () => parse(apiBaseUrl: 'https://api.proxycare.test?debug=1'),
        throwsEnvError('must not contain a query'),
      );
    });

    test('allows a plain http override in development', () {
      final env = parse(apiBaseUrl: 'http://192.168.1.20:3000');

      expect(env.apiBaseUrl, Uri.parse('http://192.168.1.20:3000'));
    });

    test('removes trailing slashes', () {
      final env = parse(
        appEnv: 'production',
        apiBaseUrl: 'https://api.proxycare.test/v1//',
      );

      expect(env.apiBaseUrl.toString(), 'https://api.proxycare.test/v1');
    });
  });

  group('APP_NAME', () {
    test('falls back to the default when blank', () {
      expect(parse(appName: '   ').appName, Env.defaultAppName);
    });

    test('trims a supplied name', () {
      expect(parse(appName: ' Proxy Care QA ').appName, 'Proxy Care QA');
    });
  });

  group('ENABLE_LOGGING', () {
    test('accepts true and false in any case', () {
      expect(parse(enableLogging: 'FALSE').enableLogging, isFalse);
      expect(
        parse(
          appEnv: 'production',
          apiBaseUrl: 'https://api.proxycare.test',
          enableLogging: 'True',
        ).enableLogging,
        isTrue,
      );
    });

    test('rejects other values', () {
      expect(
        () => parse(enableLogging: 'yes'),
        throwsEnvError('ENABLE_LOGGING'),
      );
    });
  });

  group('FEATURE_FLAGS', () {
    test('parses a comma-separated list and skips empty entries', () {
      final env = parse(featureFlags: ' new_checkout, beta_maps ,,');

      expect(env.featureFlags, {'new_checkout', 'beta_maps'});
      expect(env.isFeatureEnabled('beta_maps'), isTrue);
      expect(env.isFeatureEnabled('dark_mode'), isFalse);
    });

    test('rejects names that are not snake_case', () {
      expect(
        () => parse(featureFlags: 'new_checkout,New-Checkout'),
        throwsEnvError('"New-Checkout"'),
      );
    });

    test('cannot be modified after parsing', () {
      final env = parse(featureFlags: 'new_checkout');

      expect(() => env.featureFlags.add('other'), throwsUnsupportedError);
    });
  });

  group('validation errors', () {
    test('are all reported together', () {
      expect(
        () => parse(
          appEnv: 'production',
          enableLogging: 'maybe',
          featureFlags: 'Bad Flag',
        ),
        throwsA(
          isA<EnvConfigException>().having(
            (exception) => exception.errors,
            'errors',
            hasLength(3),
          ),
        ),
      );
    });

    test('are listed in the exception message', () {
      const exception = EnvConfigException(['first problem', 'second one']);

      expect(exception.toString(), contains('  - first problem'));
      expect(exception.toString(), contains('  - second one'));
    });
  });

  group('equality', () {
    test('two parses of the same values are equal', () {
      final first = parse(featureFlags: 'a_flag,b_flag');
      final second = parse(featureFlags: 'b_flag, a_flag');

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('different values are not equal', () {
      expect(parse(appName: 'One'), isNot(parse(appName: 'Two')));
    });
  });
  group('Supabase settings', () {
    const key = 'sb_publishable_abc123';

    String legacyJwt(String role) {
      String part(String json) =>
          base64Url.encode(utf8.encode(json)).replaceAll('=', '');
      return '${part('{"alg":"HS256"}')}.${part('{"role":"$role"}')}.sig';
    }

    test('are optional in development', () {
      final env = parse();

      expect(env.isAuthConfigured, isFalse);
      expect(env.supabaseUrl, isNull);
    });

    test('are read and normalized when given', () {
      final env = parse(
        supabaseUrl: 'https://project-ref.supabase.co/',
        supabasePublishableKey: key,
      );

      expect(env.isAuthConfigured, isTrue);
      expect(env.supabaseUrl.toString(), 'https://project-ref.supabase.co');
      expect(env.supabasePublishableKey, key);
    });

    test('a local Supabase over http is allowed in development only', () {
      expect(
        parse(
          supabaseUrl: 'http://127.0.0.1:54321',
          supabasePublishableKey: key,
        ).isAuthConfigured,
        isTrue,
      );
      expect(
        () => parse(
          appEnv: 'staging',
          apiBaseUrl: 'https://api.proxycare.test',
          supabaseUrl: 'http://project-ref.supabase.co',
          supabasePublishableKey: key,
        ),
        throwsEnvError('SUPABASE_URL must be an https URL'),
      );
    });

    test('are required in staging and production', () {
      expect(
        () => parse(
          appEnv: 'production',
          apiBaseUrl: 'https://api.proxycare.test',
          supabaseUrl: '',
          supabasePublishableKey: '',
        ),
        throwsEnvError('SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY'),
      );
    });

    test('must be given together', () {
      expect(
        () => parse(supabaseUrl: 'https://project-ref.supabase.co'),
        throwsEnvError('or neither'),
      );
    });

    test('reject secret and service-role keys', () {
      for (final secret in ['sb_secret_abc', legacyJwt('service_role')]) {
        expect(
          () => parse(
            supabaseUrl: 'https://project-ref.supabase.co',
            supabasePublishableKey: secret,
          ),
          throwsEnvError('must be a publishable key'),
        );
      }
    });

    test('accept a legacy anon key', () {
      expect(
        parse(
          supabaseUrl: 'https://project-ref.supabase.co',
          supabasePublishableKey: legacyJwt('anon'),
        ).isAuthConfigured,
        isTrue,
      );
    });
  });
}

/// Calls [Env.parse] with empty strings for every define not given, except
/// the Supabase settings, which default to valid values in staging and
/// production (where they are required) so other tests stay focused.
Env parse({
  String appEnv = '',
  String apiBaseUrl = '',
  String appName = '',
  String enableLogging = '',
  String featureFlags = '',
  String? supabaseUrl,
  String? supabasePublishableKey,
  bool requireExplicitEnvironment = false,
}) {
  final release = const {
    'staging',
    'production',
  }.contains(appEnv.trim().toLowerCase());
  return Env.parse(
    supabaseUrl:
        supabaseUrl ?? (release ? 'https://project-ref.supabase.co' : ''),
    supabasePublishableKey:
        supabasePublishableKey ?? (release ? 'sb_publishable_test' : ''),
    appEnv: appEnv,
    apiBaseUrl: apiBaseUrl,
    appName: appName,
    enableLogging: enableLogging,
    featureFlags: featureFlags,
    requireExplicitEnvironment: requireExplicitEnvironment,
  );
}

/// Expects an [EnvConfigException] with an error message containing
/// [fragment].
Matcher throwsEnvError(String fragment) {
  return throwsA(
    isA<EnvConfigException>().having(
      (exception) => exception.errors,
      'errors',
      contains(contains(fragment)),
    ),
  );
}
