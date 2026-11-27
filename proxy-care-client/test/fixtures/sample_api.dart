import 'dart:typed_data';

import 'package:dio/dio.dart' hide Headers;
import 'package:json_annotation/json_annotation.dart';
import 'package:proxy_care_client/core/network/network_config.dart';
import 'package:proxy_care_client/core/network/pagination.dart';
import 'package:proxy_care_client/core/network/request_options.dart';
import 'package:retrofit/retrofit.dart';

part 'sample_api.g.dart';

/// A DTO in the shape the generated code expects.
@JsonSerializable()
class ItemDto {
  const ItemDto({required this.id, required this.name});

  factory ItemDto.fromJson(Map<String, dynamic> json) =>
      _$ItemDtoFromJson(json);

  final String id;
  final String name;

  Map<String, dynamic> toJson() => _$ItemDtoToJson(this);
}

/// A Retrofit API using every capability the networking layer promises:
/// JSON bodies, pages, response headers, idempotency, `If-Match`, per-
/// request auth switch, upload, download, progress and
/// cancellation.
@RestApi()
abstract class SampleApi {
  factory SampleApi(Dio dio, {ParseErrorLogger? errorLogger}) = _SampleApi;

  @GET('/items')
  Future<List<ItemDto>> list();

  @GET('/items')
  Future<PageResponse<ItemDto>> page(
    @Query(PageRequest.pageParameter) int page,
    @Query(PageRequest.sizeParameter) int size,
  );

  @GET('/items/{id}')
  Future<HttpResponse<ItemDto>> get(@Path() String id);

  @POST('/items')
  Future<HttpResponse<ItemDto>> create(
    @Body() Map<String, dynamic> body,
    @Header(ApiHeaders.idempotencyKey) String idempotencyKey,
  );

  @PUT('/items/{id}')
  Future<ItemDto> replace(
    @Path() String id,
    @Body() Map<String, dynamic> body,
    @Header(ApiHeaders.ifMatch) String ifMatch,
  );

  @DELETE('/items/{id}')
  Future<void> remove(@Path() String id);

  @Extra({RequestExtra.skipAuth: true})
  @POST('/sign-in')
  Future<void> signIn(@Body() Map<String, dynamic> body);

  @MultiPart()
  @POST('/items/{id}/photo')
  Future<ItemDto> uploadPhoto(
    @Path() String id,
    @Part(name: 'photo') MultipartFile photo,
    @Part(name: 'caption') String caption,
    @SendProgress() ProgressCallback? onProgress,
    @CancelRequest() CancelToken? cancelToken,
  );

  @GET('/items/{id}/report')
  @DioResponseType(ResponseType.bytes)
  Future<HttpResponse<Uint8List>> report(
    @Path() String id,
    @ReceiveProgress() ProgressCallback? onProgress,
  );

  @GET('/slow')
  Future<List<ItemDto>> slow(@CancelRequest() CancelToken cancelToken);
}
