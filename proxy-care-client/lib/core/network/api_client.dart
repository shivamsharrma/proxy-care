import 'api_response.dart';
import 'request_options.dart';
import 'transfer.dart';

/// The app's single entry point to the HTTP API, for the data layer.
///
/// Every method:
/// * resolves [path], a resource path such as `/patients/p1`, under
///   `<API_BASE_URL>/api/v1` (`NetworkConfig.apiRoot`); never repeat the
///   prefix in [path];
/// * returns the typed payload in an [ApiResponse], decoded by [decode]
///   from the body's `data` (a collection's `page` is on
///   [ApiResponse.page]) or, with [ResponseFormat.raw], from the whole
///   body; response headers such as `ETag` are on the [ApiResponse];
/// * throws only `AppException`s (never Dio types): network errors and
///   problem details (RFC 9457) are mapped by `ErrorMapper`, unexpected
///   shapes become `ServerException.invalidResponse`.
///
/// Repositories call it inside `guardResult`, which turns those exceptions
/// into `AppFailure`s. Domain and presentation never see it.
abstract interface class ApiClient {
  /// GET [path]. Retried on transient failures by default.
  Future<ApiResponse<T>> get<T>(
    String path, {
    required JsonDecoder<T> decode,
    Map<String, Object?>? query,
    ResponseFormat format = ResponseFormat.envelope,
    ApiRequestOptions options = const ApiRequestOptions(),
  });

  /// POST [body] (JSON-encoded) to [path].
  Future<ApiResponse<T>> post<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    Map<String, Object?>? query,
    ResponseFormat format = ResponseFormat.envelope,
    ApiRequestOptions options = const ApiRequestOptions(),
  });

  /// PUT [body] to [path].
  Future<ApiResponse<T>> put<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    Map<String, Object?>? query,
    ResponseFormat format = ResponseFormat.envelope,
    ApiRequestOptions options = const ApiRequestOptions(),
  });

  /// PATCH [body] to [path].
  Future<ApiResponse<T>> patch<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    Map<String, Object?>? query,
    ResponseFormat format = ResponseFormat.envelope,
    ApiRequestOptions options = const ApiRequestOptions(),
  });

  /// DELETE [path].
  Future<ApiResponse<T>> delete<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    Map<String, Object?>? query,
    ResponseFormat format = ResponseFormat.envelope,
    ApiRequestOptions options = const ApiRequestOptions(),
  });

  /// Sends [files] and [fields] as `multipart/form-data` (POST by default).
  Future<ApiResponse<T>> upload<T>(
    String path, {
    required List<UploadFile> files,
    required JsonDecoder<T> decode,
    Map<String, String> fields = const {},
    String method = 'POST',
    ResponseFormat format = ResponseFormat.envelope,
    ApiRequestOptions options = const ApiRequestOptions(),
    TransferProgress? onProgress,
  });

  /// Downloads [path] into memory.
  Future<DownloadedFile> download(
    String path, {
    Map<String, Object?>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
    TransferProgress? onProgress,
  });
}

/// Decoder for responses whose payload is ignored (for example 204 No
/// Content, or `"data": null`).
void ignoreBody(Object? json) {}
