import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../config/app_variant.dart';
import '../config/env.dart';
import 'core_providers.dart';

/// Builds the root [ProviderContainer].
///
/// This is the single place where root-level overrides are composed. The app
/// passes [env], [variant] and its route modules in [overrides]; tests may
/// add [overrides] to replace infrastructure with fakes.
///
/// The caller owns the container and must dispose it.
ProviderContainer createAppContainer({
  required Env env,
  required AppVariant variant,
  List<Override> overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      envProvider.overrideWithValue(env),
      appVariantProvider.overrideWithValue(variant),
      ...overrides,
    ],
  );
}
