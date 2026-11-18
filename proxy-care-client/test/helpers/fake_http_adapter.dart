import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Produces the response for one request.
typedef FakeResponder = FutureOr<ResponseBody> Function(RequestOptions options);

/// What the adapter saw for one attempt (headers and extra are copied,
/// because Dio reuses the same `RequestOptions` for retries).
final class RecordedRequest {
  RecordedRequest(RequestOptions options, this.body)
    : method = options.method,
      uri = options.uri,
      headers = Map.of(options.headers),
      extra = Map.of(options.extra),
      sendTimeout = options.sendTimeout,
      receiveTimeout = options.receiveTimeout,
      connectTimeout = options.connectTimeout,
      data = options.data;

  final String method;
  final Uri uri;
  final Map<String, Object?> headers;
  final Map<String, Object?> extra;
  final Duration? sendTimeout;
  final Duration? receiveTimeout;
  final Duration? connectTimeout;
  final Object? data;

  /// The bytes sent, if the request had a body.
  final Uint8List? body;

  String get path => uri.path;
}

/// An [HttpClientAdapter] that never touches the network: it answers each
/// request with the next queued responder, then with [fallback].
final class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter([List<FakeResponder> responders = const []])
    : _responders = [...responders];

  final List<FakeResponder> _responders;

  /// Used once the queue is empty.
  FakeResponder? fallback;

  /// Every attempt, in order.
  final List<RecordedRequest> requests = [];

  /// Adds responders to the queue.
  void enqueue(Iterable<FakeResponder> responders) =>
      _responders.addAll(responders);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = requestStream == null
        ? null
        : Uint8List.fromList(
            await requestStream.expand((chunk) => chunk).toList(),
          );
    requests.add(RecordedRequest(options, body));
    final responder = _responders.isNotEmpty
        ? _responders.removeAt(0)
        : fallback ?? (throw StateError('No response for ${options.uri}'));
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Responds with [json] encoded as `application/json`.
FakeResponder respondJson(
  Object? json, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) =>
    (_) => ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );

/// Responds with raw [text].
FakeResponder respondText(
  String text, {
  int status = 200,
  String contentType = 'text/plain',
}) =>
    (_) => ResponseBody.fromString(
      text,
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );

/// Responds with raw [bytes].
FakeResponder respondBytes(
  List<int> bytes, {
  Map<String, List<String>> headers = const {},
}) =>
    (_) => ResponseBody.fromBytes(bytes, 200, headers: headers);

/// Fails the attempt like a transport error of [type].
FakeResponder failWith(DioExceptionType type) =>
    (options) => throw DioException(requestOptions: options, type: type);

/// A success body (ADR 0012) around [data]: `{"data": …}`, plus `page`
/// when [page] is given (a collection).
Map<String, Object?> dataBody(Object? data, {Map<String, Object?>? page}) => {
  'data': data,
  'page': ?page,
};

/// The `page` object of a collection response.
Map<String, Object?> pageMeta({
  String? nextCursor,
  bool? hasMore,
  int size = 20,
}) => {
  'nextCursor': nextCursor,
  'hasMore': hasMore ?? nextCursor != null,
  'size': size,
};

/// An RFC 9457 problem details body as the backend sends it (ADR 0012).
/// [errors] are `{field, code, message}` entries.
Map<String, Object?> problemBody(
  String? code, {
  int status = 500,
  String detail = 'Backend detail',
  List<Map<String, Object?>>? errors,
  String? traceId,
}) => {
  'type': 'urn:proxycare:problem:${code?.toLowerCase() ?? 'unknown'}',
  'title': 'Backend title',
  'status': status,
  'detail': detail,
  'instance': '/api/v1/items',
  'code': ?code,
  'traceId': ?traceId,
  'timestamp': '2026-11-18T09:30:00Z',
  'errors': ?errors,
};

/// One `errors` entry of a problem.
Map<String, Object?> fieldError(
  String field,
  String message, {
  String code = 'Invalid',
}) => {'field': field, 'code': code, 'message': message};

/// Responds with a problem details body for [code], sent as
/// `application/problem+json` with [status].
FakeResponder respondProblem(
  String? code, {
  required int status,
  String detail = 'Backend detail',
  List<Map<String, Object?>>? errors,
  String? traceId,
  Map<String, List<String>> headers = const {},
}) => respondJson(
  problemBody(
    code,
    status: status,
    detail: detail,
    errors: errors,
    traceId: traceId,
  ),
  status: status,
  headers: {
    Headers.contentTypeHeader: ['application/problem+json'],
    ...headers,
  },
);
