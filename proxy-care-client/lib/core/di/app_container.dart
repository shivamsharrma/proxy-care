import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../config/env.dart';
import 'core_providers.dart';

/// Builds the root [ProviderContainer].
///
/// This is the single place where root-level overrides are composed. The app
/// passes only [env]; tests may add [overrides] to replace infrastructure
/// with fakes.
///
/// The caller owns the container and must dispose it.
ProviderContainer createAppContainer({
  required Env env,
  List<Override> overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      envProvider.overrideWithValue(env),
      ...overrides,
    ],
  );
}
