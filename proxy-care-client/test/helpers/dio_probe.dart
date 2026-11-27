import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:proxy_care_client/core/error/error_mapper.dart';
import 'package:proxy_care_client/core/network/network_config.dart';
import 'package:proxy_care_client/core/network/request_options.dart';

/// What a test wants to vary on one request. Turned into Dio [Options] the
/// way a Retrofit method's annotations would (`@Header`, `@Extra`, ...).
final class CallOptions {
  const CallOptions({
    this.headers = const {},
    this.receiveTimeout,
    this.sendTimeout,
    this.cancelToken,
    this.idempotencyKey,
    this.ifMatch,
    this.skipAuth = false,
  });

  final Map<String, String> headers;
  final Duration? receiveTimeout;
  final Duration? sendTimeout;
  final CancelToken? cancelToken;
  final String? idempotencyKey;
  final String? ifMatch;
  final bool skipAuth;

  Options toDio(String method, {ResponseType? responseType}) => Options(
    method: method,
    headers: {
      ...headers,
      ApiHeaders.idempotencyKey: ?idempotencyKey,
      ApiHeaders.ifMatch: ?ifMatch,
    },
    receiveTimeout: receiveTimeout,
    sendTimeout: sendTimeout,
    responseType: responseType,
    extra: {
      if (skipAuth) RequestExtra.skipAuth: true,
    },
  );
}

/// Sends requests through a real, configured [Dio] and, like `guardResult`,
/// maps failures to `AppException`s with [ErrorMapper]. Lets interceptor
/// tests hit any path with any options without a Retrofit class.
final class DioProbe {
  const DioProbe(this.dio, {this.mapper = const ErrorMapper()});

  final Dio dio;
  final ErrorMapper mapper;

  Future<Response<Object?>> send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    CallOptions options = const CallOptions(),
    ResponseType? responseType,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      return await dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        cancelToken: options.cancelToken,
        onSendProgress: onSendProgress,
        options: options.toDio(method, responseType: responseType),
      );
    } on DioException catch (error) {
      throw mapper.map(error);
    }
  }

  Future<Response<Object?>> get(
    String path, {
    Map<String, Object?>? query,
    CallOptions options = const CallOptions(),
  }) => send('GET', path, query: query, options: options);

  Future<Response<Object?>> post(
    String path, {
    Object? body,
    CallOptions options = const CallOptions(),
  }) => send('POST', path, body: body, options: options);

  Future<Response<Object?>> put(
    String path, {
    Object? body,
    CallOptions options = const CallOptions(),
  }) => send('PUT', path, body: body, options: options);

  Future<Response<Object?>> patch(
    String path, {
    Object? body,
    CallOptions options = const CallOptions(),
  }) => send('PATCH', path, body: body, options: options);

  Future<Response<Object?>> delete(
    String path, {
    CallOptions options = const CallOptions(),
  }) => send('DELETE', path, options: options);

  Future<Uint8List> bytes(String path) async {
    final response = await send('GET', path, responseType: ResponseType.bytes);
    return Uint8List.fromList(response.data! as List<int>);
  }
}
