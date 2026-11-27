import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';
import '../network/dio_factory.dart';
import '../network/invalid_response_logger.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

// Networking providers. Data sources build their Retrofit API class from
// `dioProvider` and `parseErrorLoggerProvider`:
//
//   PatientApi(ref.watch(dioProvider),
//       errorLogger: ref.watch(parseErrorLoggerProvider))

/// The configured Dio. Closed when the container is disposed.
final dioProvider = Provider<Dio>((ref) {
  final logger = ref.watch(loggerProvider);
  final dio = DioFactory(
    baseUrl: ref.watch(envProvider).apiBaseUrl,
    tokens: ref.watch(authenticationSessionProvider),
    log: logger.info,
  ).create();
  ref.onDispose(dio.close);
  return dio;
});

/// The `errorLogger` of every Retrofit API class: turns a body that does
/// not match its DTO into `ServerException.invalidResponse`.
final parseErrorLoggerProvider = Provider<InvalidResponseLogger>(
  (ref) => const InvalidResponseLogger(),
);
