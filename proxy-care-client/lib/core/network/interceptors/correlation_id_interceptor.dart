import 'package:dio/dio.dart';

import '../../utils/uuid.dart';
import '../network_config.dart';
import '../request_options.dart';

/// Gives every logical request a correlation ID and sends it as the
/// `X-Correlation-Id` header.
///
/// An ID already on the request (set by the caller in the header) is
/// propagated; otherwise one is generated. The ID is stored in
/// `RequestOptions.extra`, which retries reuse, so every attempt of the same
/// logical request carries the same ID.
final class CorrelationIdInterceptor extends Interceptor {
  /// Creates the interceptor. [generate] makes new IDs (UUID v4).
  CorrelationIdInterceptor({String Function()? generate})
    : _generate = generate ?? generateUuidV4;

  final String Function() _generate;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final existing =
        options.extra[RequestExtra.correlationId] as String? ??
        options.headers[ApiHeaders.correlationId] as String?;
    final id = existing ?? _generate();
    options.extra[RequestExtra.correlationId] = id;
    options.headers[ApiHeaders.correlationId] = id;
    handler.next(options);
  }
}
