import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';
import '../network/api_client.dart';
import '../network/dio_api_client.dart';
import '../network/dio_factory.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

// Networking providers. Only the data layer reads `apiClientProvider`;
// `dioProvider` is for the networking layer itself.

/// The configured Dio. Closed when the container is disposed.
final dioProvider = Provider<Dio>((ref) {
  final logger = ref.watch(loggerProvider);
  final dio = DioFactory(
    baseUrl: ref.watch(envProvider).apiBaseUrl,
    tokens: ref.watch(authenticationSessionProvider),
    recovery: ref.watch(sessionTokenRecoveryProvider),
    log: logger.info,
    detailedLogging: kDebugMode,
  ).create();
  ref.onDispose(dio.close);
  return dio;
});

/// The app's API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  return DioApiClient(
    ref.watch(dioProvider),
    errorMapper: ref.watch(errorMapperProvider),
  );
});
