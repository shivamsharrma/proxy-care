import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../network_config.dart';
import '../request_options.dart';

/// Gives every logical request a correlation ID and sends it as the
/// `X-Correlation-Id` header.
///
/// The ID is stored in `RequestOptions.extra`, which retries reuse, so every
/// attempt of the same logical request carries the same ID.
final class CorrelationIdInterceptor extends Interceptor {
  static const Uuid _uuid = Uuid();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id =
        options.extra[RequestExtra.correlationId] as String? ?? _uuid.v4();
    options.extra[RequestExtra.correlationId] = id;
    options.headers[ApiHeaders.correlationId] = id;
    handler.next(options);
  }
}
