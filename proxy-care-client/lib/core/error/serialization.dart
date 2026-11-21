import 'package:json_annotation/json_annotation.dart';

import 'app_exception.dart';

/// Decodes a response payload with [parse] (usually `Dto.fromJson`) and
/// turns a payload that does not match the expected shape into a
/// [ServerException.invalidResponse].
///
/// Generated `fromJson` code reports a wrong shape as a `TypeError` (for
/// example `null` where a `String` was expected) or, with
/// `checked: true`, as a `CheckedFromJsonException`. Catching `TypeError`
/// is limited to this call, so a `TypeError` anywhere else still surfaces
/// as the programming error it is.
T decodeResponse<T>(T Function() parse) {
  try {
    return parse();
  } on CheckedFromJsonException catch (error) {
    throw ServerException.invalidResponse(cause: error);
  } on FormatException catch (error) {
    throw ServerException.invalidResponse(cause: error);
  } on TypeError catch (error) {
    throw ServerException.invalidResponse(cause: error);
  }
}
