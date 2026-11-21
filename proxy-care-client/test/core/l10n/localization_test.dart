import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/l10n/generated/app_localizations.dart';

void main() {
  test('English is the only, and initial, locale', () {
    expect(AppLocalizations.supportedLocales, [const Locale('en')]);
  });

  test('supports interpolation and pluralization', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(l10n.a11yStepProgress(2, 5), 'Step 2 of 5');
    expect(l10n.durationHours(1), '1 hour');
    expect(l10n.durationHours(3), '3 hours');
  });

  testWidgets('an unsupported device locale falls back to English', (
    tester,
  ) async {
    late Locale resolved;
    late String label;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi', 'IN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            resolved = Localizations.localeOf(context);
            label = AppLocalizations.of(context).a11yBack;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved, const Locale('en'));
    expect(label, 'Back');
  });

  test('every ARB message has a description (translator context)', () {
    final arb = jsonDecode(
      File('lib/core/l10n/arb/app_en.arb').readAsStringSync(),
    ) as Map<String, Object?>;
    final messages = arb.keys.where((key) => !key.startsWith('@'));

    for (final key in messages) {
      final meta = arb['@$key'];
      expect(
        meta is Map && meta['description'] is String,
        isTrue,
        reason: '$key has no description',
      );
    }
  });
}
