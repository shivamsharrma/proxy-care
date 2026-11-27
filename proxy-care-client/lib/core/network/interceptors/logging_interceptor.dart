import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

import '../request_options.dart';

/// Writes one line per request attempt: method, endpoint path, status (or
/// failure type) and duration, e.g.
/// `GET /api/v1/bookings → 200 in 182 ms [3b24…]`.
///
/// Privacy: the line never contains the host, query, headers or bodies, so
/// no credentials or healthcare information reach the log.
final class LoggingInterceptor extends Interceptor {
  /// Creates the interceptor, writing to [log].
  LoggingInterceptor({required this.log});

  /// Where log lines go.
  final void Function(String message) log;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[RequestExtra.startedAt] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    log('${_label(options)} → ${response.statusCode}${_duration(options)}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final outcome = err.response?.statusCode?.toString() ?? err.type.name;
    log('${_label(options)} → $outcome${_duration(options)}');
    handler.next(err);
  }

  String _label(RequestOptions options) {
    final retry = options.attempt;
    final id = options.extra[RequestExtra.correlationId] as String?;
    return '${options.method} ${options.uri.path}'
        '${retry == 0 ? '' : ' (retry $retry)'}'
        '${id == null ? '' : ' [$id]'}';
  }

  String _duration(RequestOptions options) {
    final started = options.extra[RequestExtra.startedAt] as DateTime?;
    if (started == null) return '';
    return ' in ${DateTime.now().difference(started).inMilliseconds} ms';
  }
}
