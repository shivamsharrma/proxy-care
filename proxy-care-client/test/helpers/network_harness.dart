import 'package:dio/dio.dart';
import 'package:proxy_care_client/core/network/access_token_provider.dart';
import 'package:proxy_care_client/core/network/dio_factory.dart';
import 'package:proxy_care_client/core/network/invalid_response_logger.dart';
import 'package:proxy_care_client/core/network/public_endpoints.dart';

import '../fixtures/sample_api.dart';
import 'dio_probe.dart';
import 'fake_http_adapter.dart';

/// A controllable access token.
final class FakeTokens implements AccessTokenProvider {
  FakeTokens({this.token, this.error});

  /// Returned by [getAccessToken].
  String? token;

  /// Thrown by [getAccessToken] when set.
  Object? error;

  @override
  Future<String?> getAccessToken() async {
    if (error case final error?) throw error;
    return token;
  }
}

/// The real networking stack (factory, interceptors, a Retrofit API class)
/// over a [FakeHttpAdapter]: no network, no real waiting.
final class NetworkHarness {
  NetworkHarness({
    List<FakeResponder> responses = const [],
    FakeTokens? tokens,
    PublicEndpoints publicEndpoints = const PublicEndpoints(),
  }) : adapter = FakeHttpAdapter(responses),
       tokens = tokens ?? FakeTokens() {
    final dio = DioFactory(
      baseUrl: baseUrl,
      tokens: this.tokens,
      publicEndpoints: publicEndpoints,
      log: logs.add,
      adapter: adapter,
      retryDelays: const [],
    ).create();
    this.dio = dio;
    client = DioProbe(dio);
    api = SampleApi(dio, errorLogger: const InvalidResponseLogger());
  }

  /// The API base URL used by the harness.
  static final Uri baseUrl = Uri.parse('https://api.proxycare.test');

  final FakeHttpAdapter adapter;
  final FakeTokens tokens;

  /// Log lines written by the logging interceptor.
  final List<String> logs = [];

  /// The configured Dio.
  late final Dio dio;

  /// Sends any request through [dio], mapping errors like `guardResult`.
  late final DioProbe client;

  /// A Retrofit API class over [dio].
  late final SampleApi api;
}
