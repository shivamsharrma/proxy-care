import 'package:dio/dio.dart';

import '../../security/redactor.dart';
import '../request_options.dart';

/// Writes one line per request attempt: method, endpoint path, status (or
/// failure type) and duration, e.g.
/// `GET /api/v1/bookings → 200 in 182 ms [3b24…]`.
///
/// Privacy: the line never contains the host, query values, headers or
/// bodies, so no credentials or healthcare information reach the log.
/// [detailed] (debug builds only) adds headers with secrets masked and the
/// names (not values) of query parameters. Bodies are logged only with
/// [logBodies], and then with every sensitive field masked by [redactor].
final class LoggingInterceptor extends Interceptor {
  /// Creates the interceptor, writing to [log].
  LoggingInterceptor({
    required this.log,
    this.detailed = false,
    this.logBodies = false,
    this.redactor = const Redactor(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Where log lines go.
  final void Function(String message) log;

  /// Adds masked headers and query parameter names (debug builds).
  final bool detailed;

  /// Adds masked request and response bodies. Off by default.
  final bool logBodies;

  /// Masks sensitive values.
  final Redactor redactor;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[RequestExtra.startedAt] = _clock();
    if (detailed) {
      final query = options.uri.queryParameters.keys.join(', ');
      log(
        '${_label(options)} → sending'
        '${query.isEmpty ? '' : ' (query: $query)'}'
        ' headers: ${redactor.headers(options.headers)}'
        '${logBodies ? ' body: ${redactor.json(options.data)}' : ''}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    final body = detailed && logBodies
        ? ' body: ${redactor.json(response.data)}'
        : '';
    log(
      '${_label(options)} → ${response.statusCode}${_duration(options)}$body',
    );
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
    final retry = options.extra[RequestExtra.retryCount] as int?;
    final id = options.extra[RequestExtra.correlationId] as String?;
    return '${options.method} ${options.uri.path}'
        '${retry == null ? '' : ' (retry $retry)'}'
        '${id == null ? '' : ' [$id]'}';
  }

  String _duration(RequestOptions options) {
    final started = options.extra[RequestExtra.startedAt] as DateTime?;
    if (started == null) return '';
    return ' in ${_clock().difference(started).inMilliseconds} ms';
  }
}
