import 'dart:math';

final Random _random = Random.secure();

/// A random (version 4) UUID, e.g. `3b241101-e2bb-4255-8caf-4136c566a962`.
///
/// Uses a cryptographically secure generator. Used for correlation IDs and
/// idempotency keys, which must not be guessable or collide.
String generateUuidV4() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = [
    for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
