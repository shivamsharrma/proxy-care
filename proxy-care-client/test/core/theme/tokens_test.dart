import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/theme/app_density.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_colors.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_elevation.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_palette.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_shape.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_sizes.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_spacing.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_typography.dart';

import '../../helpers/pump_themed.dart';

/// Hex value of an opaque color, e.g. `#006A60`.
String hex(Color color) {
  final argb = color.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'
      .toUpperCase();
}

void main() {
  group('palette matches section 1 of the design system', () {
    // Token → hex, copied from claude/proxycare-design-system.md.
    final expected = <String, Color>{
      '#006A60': PcPalette.primary500,
      '#00504A': PcPalette.primary600,
      '#9EF2E4': PcPalette.primary200,
      '#D7F5EF': PcPalette.primary100,
      '#E6F4F1': PcPalette.primary50,
      '#00201C': PcPalette.primary900,
      '#CDE8E2': PcPalette.secondary100,
      '#051F1C': PcPalette.secondary900,
      '#FFDCC4': PcPalette.warning100,
      '#8B5000': PcPalette.warning500,
      '#2F1500': PcPalette.warning900,
      '#FFDAD6': PcPalette.error100,
      '#BA1A1A': PcPalette.error500,
      '#410002': PcPalette.error900,
      '#FFF1EF': PcPalette.error50,
      '#FFFFFF': PcPalette.neutral0,
      '#F9FCFB': PcPalette.neutral25,
      '#F4FBF8': PcPalette.neutral50,
      '#EEF5F2': PcPalette.neutral75,
      '#EEF2F0': PcPalette.neutral80,
      '#E9EFEC': PcPalette.neutral100,
      '#E3EAE7': PcPalette.neutral150,
      '#DDE4E1': PcPalette.neutral200,
      '#BEC9C6': PcPalette.neutral300,
      '#6F7977': PcPalette.neutral500,
      '#5B6562': PcPalette.neutral550,
      '#3F4946': PcPalette.neutral700,
      '#2B3230': PcPalette.neutral800,
      '#ECF2EF': PcPalette.neutral850,
      '#161D1B': PcPalette.neutral900,
      '#E6EEE9': PcPalette.neutral110,
      '#D5E0DA': PcPalette.neutral220,
    };

    for (final MapEntry(key: hexValue, value: color) in expected.entries) {
      test(hexValue, () {
        expect(hex(color), hexValue);
        expect(color.a, 1.0);
      });
    }

    test('scrim is rgba(0,0,0,.32)', () {
      expect(PcPalette.scrim.r, 0);
      expect(PcPalette.scrim.a, closeTo(0.32, 0.005));
    });
  });

  group('semantic roles', () {
    const colors = PcColors.light;

    test('aliases point at the documented neutrals', () {
      expect(colors.bg, PcPalette.neutral50);
      expect(colors.surface, PcPalette.neutral0);
      expect(colors.surfaceContainer, PcPalette.neutral100);
      expect(colors.surfaceContainerHigh, PcPalette.neutral150);
      expect(colors.text, PcPalette.neutral900);
      expect(colors.textMuted, PcPalette.neutral700);
      expect(colors.border, PcPalette.neutral200);
      expect(colors.divider, PcPalette.neutral80);
      expect(colors.outline, PcPalette.neutral500);
      expect(colors.disabledBg, PcPalette.neutral200);
      expect(colors.disabledText, PcPalette.neutral500);
    });

    test('success re-uses the brand hue and info has no blue', () {
      expect(colors.successTone.container, PcPalette.primary200);
      expect(colors.successTone.accent, PcPalette.primary500);
      expect(colors.successTone.onContainer, PcPalette.primary900);
      expect(colors.infoTone.container, PcPalette.neutral100);
      expect(colors.infoTone.onContainer, PcPalette.neutral700);
    });

    test('each tone resolves to its triple', () {
      expect(colors.tone(PcTone.warning), same(colors.warningTone));
      expect(colors.tone(PcTone.error), same(colors.errorTone));
      expect(colors.tone(PcTone.success), same(colors.successTone));
      expect(colors.tone(PcTone.info), same(colors.infoTone));
      expect(colors.tone(PcTone.neutral), same(colors.neutralTone));
    });
  });

  group('accessibility contrast (usage rules, "Accessibility")', () {
    test('stated text pairs meet 4.5:1', () {
      expect(
        contrastRatio(PcPalette.neutral700, PcPalette.neutral50),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(PcPalette.warning500, PcPalette.warning100),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(PcPalette.primary100, PcPalette.primary500),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('control outline meets 3:1 on the background and surface', () {
      expect(
        contrastRatio(PcColors.light.outline, PcColors.light.bg),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrastRatio(PcColors.light.outline, PcColors.light.surface),
        greaterThanOrEqualTo(3),
      );
    });

    test('each tone on-color meets 4.5:1 on its container', () {
      for (final tone in PcTone.values) {
        final colors = PcColors.light.tone(tone);
        expect(
          contrastRatio(colors.onContainer, colors.container),
          greaterThanOrEqualTo(4.5),
          reason: '$tone',
        );
      }
    });
  });

  group('type scale matches section 2', () {
    // name: (style, size, line height, weight, tracking)
    final expected = <String, (TextStyle, double, double, FontWeight, double)>{
      'display': (PcTypeScale.display, 36, 44, FontWeight.w500, -0.25),
      'h1': (PcTypeScale.h1, 28, 36, FontWeight.w400, 0),
      'h2': (PcTypeScale.h2, 24, 32, FontWeight.w400, 0),
      'h3': (PcTypeScale.h3, 22, 28, FontWeight.w400, 0),
      'title-md': (PcTypeScale.titleMd, 18, 24, FontWeight.w500, 0),
      'title-sm': (PcTypeScale.titleSm, 16, 24, FontWeight.w500, 0),
      'body-lg': (PcTypeScale.bodyLg, 16, 24, FontWeight.w400, 0),
      'body-md': (PcTypeScale.bodyMd, 14, 20, FontWeight.w400, 0),
      'body-sm': (PcTypeScale.bodySm, 12, 16, FontWeight.w400, 0.4),
      'list-title': (PcTypeScale.listTitle, 15, 20, FontWeight.w500, 0),
      'list-meta': (PcTypeScale.listMeta, 13, 18, FontWeight.w400, 0),
      'button': (PcTypeScale.button, 16, 24, FontWeight.w500, 0.1),
      'button-sm': (PcTypeScale.buttonSm, 14, 20, FontWeight.w500, 0.1),
      'section-label': (
        PcTypeScale.sectionLabel,
        14,
        20,
        FontWeight.w500,
        0.1,
      ),
      'field-label': (PcTypeScale.fieldLabel, 12, 16, FontWeight.w400, 0),
      'overline': (PcTypeScale.overline, 12, 16, FontWeight.w500, 0.5),
      'badge': (PcTypeScale.badge, 13, 16, FontWeight.w500, 0),
      'nav-label': (PcTypeScale.navLabel, 12, 16, FontWeight.w500, 0),
      'micro': (PcTypeScale.micro, 11, 14, FontWeight.w400, 0),
      'amount-xl': (PcTypeScale.amountXl, 32, 40, FontWeight.w500, 0),
      'amount-lg': (PcTypeScale.amountLg, 26, 32, FontWeight.w500, 0),
      'amount-md': (PcTypeScale.amountMd, 22, 28, FontWeight.w500, 0),
      'otp-digit': (PcTypeScale.otpDigit, 24, 32, FontWeight.w500, 0),
      'code': (PcTypeScale.code, 22, 28, FontWeight.w500, 4),
      'c-body-lg': (PcTypeScale.cBodyLg, 18, 26, FontWeight.w400, 0),
      'c-body-option': (PcTypeScale.cBodyOption, 17, 24, FontWeight.w400, 0),
      'c-body-md': (PcTypeScale.cBodyMd, 15, 22, FontWeight.w400, 0),
      'c-section-label': (
        PcTypeScale.cSectionLabel,
        16,
        24,
        FontWeight.w500,
        0,
      ),
      'c-button': (PcTypeScale.cButton, 18, 24, FontWeight.w500, 0.1),
      'c-field-label': (PcTypeScale.cFieldLabel, 13, 16, FontWeight.w400, 0),
      'c-nav-label': (PcTypeScale.cNavLabel, 13, 16, FontWeight.w500, 0),
    };

    for (final MapEntry(:key, :value) in expected.entries) {
      test(key, () {
        final (style, size, lineHeight, weight, tracking) = value;
        expect(style.fontSize, size);
        expect(style.fontSize! * style.height!, closeTo(lineHeight, 0.001));
        expect(style.fontWeight, weight);
        expect(style.letterSpacing, tracking);
        // Native platform typeface for Latin text; bundled Devanagari.
        expect(style.fontFamily, isNull);
        expect(style.fontFamilyFallback, ['Noto Sans Devanagari']);
      });
    }

    test('comfortable density steps up body and control text', () {
      const standard = PcTextStyles.standard;
      const comfortable = PcTextStyles.comfortable;
      expect(standard.bodyLg, PcTypeScale.bodyLg);
      expect(comfortable.bodyLg, PcTypeScale.cBodyLg);
      expect(comfortable.bodyMd, PcTypeScale.cBodyMd);
      expect(comfortable.optionLabel, PcTypeScale.cBodyOption);
      expect(comfortable.sectionLabel, PcTypeScale.cSectionLabel);
      expect(comfortable.fieldLabel, PcTypeScale.cFieldLabel);
      expect(comfortable.navLabel, PcTypeScale.cNavLabel);
      expect(standard.stepCaption, PcTypeScale.bodySm);
      expect(comfortable.stepCaption.fontSize, 14);
      expect(comfortable.badge.fontSize, 15);
    });
  });

  test('spacing scale is the 4px scale of section 3', () {
    expect(
      [
        PcSpacing.spaceHalf,
        PcSpacing.space1,
        PcSpacing.space2,
        PcSpacing.space3,
        PcSpacing.space4,
        PcSpacing.space5,
        PcSpacing.space6,
        PcSpacing.space7,
        PcSpacing.space8,
        PcSpacing.space10,
        PcSpacing.space12,
      ],
      [2, 4, 8, 12, 16, 20, 24, 28, 32, 40, 48],
    );
    expect(PcSpacing.textInset, 24);
    expect(PcSpacing.cardInset, 16);
  });

  test('radii, borders and shadows match section 4', () {
    expect(
      [
        PcRadii.xs,
        PcRadii.sm,
        PcRadii.md,
        PcRadii.lg,
        PcRadii.xl,
        PcRadii.xxl,
        PcRadii.xxxl,
      ],
      [2, 4, 8, 12, 16, 20, 28],
    );
    expect(PcBorders.thin, 1);
    expect(PcBorders.thick, 2);

    final s1 = PcShadows.shadow1.single;
    expect(s1.offset, const Offset(0, 4));
    expect(s1.blurRadius, 12);
    expect(s1.color.a, closeTo(0.25, 0.005));
    final s3 = PcShadows.shadow3.single;
    expect(s3.offset, const Offset(0, 8));
    expect(s3.blurRadius, 24);
    expect(s3.color.a, closeTo(0.2, 0.005));
  });

  test('fixed sizes and density metrics match sections 3 and 6', () {
    expect(PcSizes.frame, 390);
    expect(PcSizes.appBar, 64);
    expect(PcSizes.touch, 48);
    expect(
      [PcSizes.iconSm, PcSizes.iconMd, PcSizes.iconLg],
      [18, 20, 24],
    );
    expect(AppDensity.standard.metrics.screenActionHeight, 56);
    expect(AppDensity.comfortable.metrics.screenActionHeight, 64);
    expect(AppDensity.standard.metrics.inputHeight, 56);
    expect(AppDensity.comfortable.metrics.inputHeight, 60);
    expect(AppDensity.standard.metrics.navBarHeight, 80);
    expect(AppDensity.comfortable.metrics.navBarHeight, 84);
    expect(AppDensity.standard.metrics.badgeHeight, 28);
    expect(AppDensity.comfortable.metrics.badgeHeight, 32);
  });
}
