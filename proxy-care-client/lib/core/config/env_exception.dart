/// Thrown when the compile-time environment configuration is invalid.
class EnvConfigException implements Exception {
  /// Creates an exception that lists every invalid value in [errors].
  const EnvConfigException(this.errors);

  /// One human-readable message per invalid value.
  final List<String> errors;

  @override
  String toString() {
    final details = errors.map((error) => '  - $error').join('\n');
    return 'Invalid environment configuration:\n$details';
  }
}
