import '../auth/authorization/authorization.dart';
import 'env_exception.dart';

/// Which app this build is: the User app or the Caretaker app.
///
/// Chosen at compile time with `--dart-define=APP_VARIANT=user|caretaker`
/// (the Android flavor of the same name sets the app id and name; iOS
/// schemes are still to do, see README). Call [AppVariant.fromEnvironment] once at start-up; call
/// [AppVariant.parse] directly from tests and tooling.
///
/// **Not a security boundary.** The variant only decides which screens the
/// app offers and the role it signs up as; the server checks every role.
enum AppVariant {
  /// The family member's app (`com.proxycare.user`, "proxy-care").
  user(Role.user),

  /// The caretaker's app (`com.proxycare.caretaker`, "proxy-caretaker").
  caretaker(Role.caretaker);

  const AppVariant(this.role);

  /// Reads the compile-time define and validates it.
  ///
  /// Throws an [EnvConfigException] when it is missing or unknown.
  factory AppVariant.fromEnvironment() =>
      AppVariant.parse(const String.fromEnvironment(appVariantKey));

  /// Validates a raw define value. There is no default: a build that does
  /// not name its app is a configuration error.
  ///
  /// Throws an [EnvConfigException] naming [appVariantKey] when [raw] is
  /// empty or not one of the variant names.
  factory AppVariant.parse(String raw) {
    final value = raw.trim().toLowerCase();
    final variant = AppVariant.values.asNameMap()[value];
    if (variant != null) return variant;
    final allowed = AppVariant.values.map((v) => v.name).join(', ');
    throw EnvConfigException([
      value.isEmpty
          ? '$appVariantKey is required; use one of $allowed.'
          : '$appVariantKey must be one of $allowed; got "$raw".',
    ]);
  }

  /// Name of the define that selects the app variant.
  static const appVariantKey = 'APP_VARIANT';

  /// The role this app signs up as.
  final Role role;
}
