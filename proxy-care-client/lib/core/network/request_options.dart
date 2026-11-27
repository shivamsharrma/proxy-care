/// Keys of `RequestOptions.extra` that carry client metadata through the
/// interceptor chain. [skipAuth] is set by the caller with Retrofit's
/// `@Extra`; the rest are set by interceptors.
abstract final class RequestExtra {
  /// `bool`: skip `AuthInterceptor` (sign-in, token refresh).
  ///
  /// ```dart
  /// @Extra({RequestExtra.skipAuth: true})
  /// @POST('/sign-in')
  /// Future<void> signIn(@Body() Map<String, dynamic> body);
  /// ```
  static const String skipAuth = 'pc.skipAuth';

  /// `String`: correlation ID of the request.
  static const String correlationId = 'pc.correlationId';

  /// `DateTime`: when the current attempt was handed to the adapter.
  static const String startedAt = 'pc.startedAt';
}
