import 'package:uuid/uuid.dart';

/// Idempotency keys for writes that must not happen twice (payments,
/// bookings). Generate one per logical operation, keep it while the user
/// retries that operation, and pass it as the `Idempotency-Key` header
/// (`ApiHeaders.idempotencyKey`).
abstract final class IdempotencyKey {
  static const Uuid _uuid = Uuid();

  /// A new random key (a version 4 UUID from a secure generator).
  static String generate() => _uuid.v4();
}
