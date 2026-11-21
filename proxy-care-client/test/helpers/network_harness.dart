import 'package:proxy_care_client/core/network/access_token_provider.dart';
import 'package:proxy_care_client/core/network/dio_api_client.dart';
import 'package:proxy_care_client/core/network/dio_factory.dart';
import 'package:proxy_care_client/core/network/public_endpoints.dart';

import 'fake_http_adapter.dart';

/// Controllable tokens and 401 recovery that record their use.
final class FakeTokens implements AccessTokenProvider, UnauthorizedRecovery {
  FakeTokens({this.token, this.recovered, this.recoveryError});

  /// Returned by [getAccessToken].
  String? token;

  /// Returned (and made current) by [recoverAccessToken].
  String? recovered;

  /// Thrown by [recoverAccessToken] when set.
  Object? recoveryError;

  /// Tokens passed to [recoverAccessToken].
  final List<String> recoveries = [];

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<String?> recoverAccessToken({required String rejectedToken}) async {
    recoveries.add(rejectedToken);
    if (recoveryError case final error?) throw error;
    if (recovered != null) token = recovered;
    return recovered;
  }
}

/// The real networking stack (factory, interceptors, client) over a
/// [FakeHttpAdapter]: no network, no real waiting.
final class NetworkHarness {
  NetworkHarness({
    List<FakeResponder> responses = const [],
    FakeTokens? tokens,
    this.detailedLogging = false,
    PublicEndpoints publicEndpoints = const PublicEndpoints(),
  }) : adapter = FakeHttpAdapter(responses),
       tokens = tokens ?? FakeTokens() {
    final dio = DioFactory(
      baseUrl: baseUrl,
      tokens: this.tokens,
      recovery: this.tokens,
      publicEndpoints: publicEndpoints,
      log: logs.add,
      detailedLogging: detailedLogging,
      adapter: adapter,
      retryDelay: (delay) async => delays.add(delay),
    ).create();
    client = DioApiClient(dio);
  }

  /// The API base URL used by the harness.
  static final Uri baseUrl = Uri.parse('https://api.proxycare.test');

  final FakeHttpAdapter adapter;
  final FakeTokens tokens;
  final bool detailedLogging;

  /// Log lines written by the logging interceptor.
  final List<String> logs = [];

  /// Backoff delays the retry interceptor asked for.
  final List<Duration> delays = [];

  late final DioApiClient client;
}
