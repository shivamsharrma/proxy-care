/// Optional integration point for biometric unlock (not implemented).
///
/// A future implementation (for example over `local_auth`) would ask the
/// user to confirm their identity before the app shows signed-in content,
/// after a cold start or a long time in the background. It only gates the
/// UI: it never reads, returns or stores tokens, which stay inside the
/// identity provider's secure session storage. See AUTHENTICATION.md.
abstract interface class BiometricGate {
  /// Whether biometric confirmation can be offered on this device.
  Future<bool> isAvailable();

  /// Asks the user to confirm; [reason] is shown by the platform prompt.
  Future<BiometricResult> confirm({required String reason});
}

/// The outcome of a biometric prompt.
enum BiometricResult {
  /// The user confirmed.
  confirmed,

  /// The user cancelled or failed.
  rejected,

  /// Biometrics are unavailable; the app continues without them.
  unavailable,
}

/// The MVP gate: biometrics are never required.
final class DisabledBiometricGate implements BiometricGate {
  /// Creates a disabled gate.
  const DisabledBiometricGate();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<BiometricResult> confirm({required String reason}) async =>
      BiometricResult.unavailable;
}
