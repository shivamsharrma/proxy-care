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
