import '../utils/uuid.dart';

/// Idempotency keys for writes that must not happen twice (payments,
/// bookings). Generate one per logical operation, keep it while the user
/// retries that operation, and pass it as `ApiRequestOptions.idempotencyKey`.
abstract final class IdempotencyKey {
  /// A new random key.
  static String generate() => generateUuidV4();
}
