import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Prepares [options] to be sent again (auth replay or retry). Returns
/// false when its body cannot be sent twice, in which case the caller must
/// give up and keep the original failure.
///
/// * No body, JSON values (maps, lists, strings, numbers, booleans) and
///   byte arrays are replayable as they are.
/// * A multipart body is cloned (each copy can be sent once); one whose
///   parts cannot be recreated is not replayable.
/// * A stream has been consumed and is never replayable.
///
/// Headers, query parameters, the cancel token and the idempotency key are
/// on [options] and are kept.
bool prepareForReplay(RequestOptions options) {
  final data = options.data;
  switch (data) {
    case null || Map<Object?, Object?>() || List<Object?>():
    case String() || num() || bool() || Uint8List():
      return true;
    case FormData():
      try {
        options.data = data.clone();
        return true;
      } on Object {
        return false;
      }
    default:
      return false;
  }
}
