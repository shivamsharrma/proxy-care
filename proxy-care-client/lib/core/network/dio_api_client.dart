import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../error/error_mapper.dart';
import 'api_client.dart';
import 'api_response.dart';
import 'network_config.dart';
import 'request_options.dart';
import 'response_parser.dart';
import 'transfer.dart';

/// [ApiClient] backed by Dio. Built by `DioFactory`; the only class that
/// calls Dio's request methods.
final class DioApiClient implements ApiClient {
  /// Creates a client over [dio].
  const DioApiClient(
    this._dio, {
    this.errorMapper = const ErrorMapper(),
    ResponseParser? parser,
  }) : _parser = parser ?? const ResponseParser();

  final Dio _dio;
  final ResponseParser _parser;

  /// Maps Dio errors to `AppException`s.
  final ErrorMapper errorMapper;

  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    required JsonDecoder<T> decode,
    Map<String, Object?>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _send(
    'GET',
    path,
    decode: decode,
    query: query,
    options: options,
  );

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    Map<String, Object?>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _send(
    'POST',
    path,
    decode: decode,
    body: body,
    query: query,
    options: options,
  );

  @override
  Future<ApiResponse<T>> put<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    Map<String, Object?>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _send(
    'PUT',
    path,
    decode: decode,
    body: body,
    query: query,
    options: options,
  );

  @override
  Future<ApiResponse<T>> patch<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    Map<String, Object?>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _send(
    'PATCH',
    path,
    decode: decode,
    body: body,
    query: query,
    options: options,
  );

  @override
  Future<ApiResponse<T>> delete<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    Map<String, Object?>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _send(
    'DELETE',
    path,
    decode: decode,
    body: body,
    query: query,
    options: options,
  );

  @override
  Future<ApiResponse<T>> upload<T>(
    String path, {
    required List<UploadFile> files,
    required JsonDecoder<T> decode,
    Map<String, String> fields = const {},
    String method = 'POST',
    ApiRequestOptions options = const ApiRequestOptions(),
    TransferProgress? onProgress,
  }) {
    final form = FormData()
      ..fields.addAll(fields.entries)
      ..files.addAll([
        for (final file in files)
          MapEntry(
            file.field,
            MultipartFile.fromBytes(
              file.bytes,
              filename: file.filename,
              contentType: file.contentType == null
                  ? null
                  : DioMediaType.parse(file.contentType!),
            ),
          ),
      ]);
    return _send(
      method,
      path,
      decode: decode,
      body: form,
      options: options,
      onSendProgress: onProgress,
    );
  }

  @override
  Future<DownloadedFile> download(
    String path, {
    Map<String, Object?>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
    TransferProgress? onProgress,
  }) async {
    final response = await _request<List<int>>(
      'GET',
      path,
      query: query,
      options: options,
      responseType: ResponseType.bytes,
      onReceiveProgress: onProgress,
    );
    final data = response.data ?? const <int>[];
    return DownloadedFile(
      bytes: data is Uint8List ? data : Uint8List.fromList(data),
      contentType: response.headers.value(Headers.contentTypeHeader),
      filename: _filename(response.headers.value('content-disposition')),
    );
  }

  Future<ApiResponse<T>> _send<T>(
    String method,
    String path, {
    required JsonDecoder<T> decode,
    required ApiRequestOptions options,
    Object? body,
    Map<String, Object?>? query,
    TransferProgress? onSendProgress,
  }) async {
    final response = await _request<Object?>(
      method,
      path,
      body: body,
      query: query,
      options: options,
      onSendProgress: onSendProgress,
    );
    return _parser.parse(
      response.data,
      decode,
      statusCode: response.statusCode ?? 200,
      headers: response.headers.map,
    );
  }

  Future<Response<R>> _request<R>(
    String method,
    String path, {
    required ApiRequestOptions options,
    Object? body,
    Map<String, Object?>? query,
    ResponseType? responseType,
    TransferProgress? onSendProgress,
    TransferProgress? onReceiveProgress,
  }) async {
    try {
      return await _dio.request<R>(
        path,
        data: body,
        queryParameters: query,
        cancelToken: options.cancellation?.cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        options: dioOptions(
          method,
          options,
          hasBody: body != null,
          responseType: responseType,
        ),
      );
    } on DioException catch (error) {
      throw errorMapper.map(error);
    }
  }

  /// The Dio [Options] for one request.
  static Options dioOptions(
    String method,
    ApiRequestOptions options, {
    required bool hasBody,
    ResponseType? responseType,
  }) {
    return Options(
      method: method,
      headers: {
        ...options.headers,
        ApiHeaders.idempotencyKey: ?options.idempotencyKey,
        ApiHeaders.ifMatch: ?options.ifMatch,
      },
      receiveTimeout: options.receiveTimeout,
      // Without a body there is nothing to time out on, and on web Dio
      // warns about a send timeout set on a bodiless request.
      sendTimeout: hasBody ? options.sendTimeout : Duration.zero,
      responseType: responseType,
      extra: {
        if (options.skipAuth) RequestExtra.skipAuth: true,
        RequestExtra.retryPolicy: ?options.retry,
      },
    );
  }

  /// The file name in a `Content-Disposition` header, if any.
  static String? _filename(String? disposition) {
    if (disposition == null) return null;
    final match = RegExp(
      r'''filename\*?=(?:UTF-8'')?"?([^";]+)"?''',
      caseSensitive: false,
    ).firstMatch(disposition);
    return match == null ? null : Uri.decodeComponent(match.group(1)!);
  }
}
