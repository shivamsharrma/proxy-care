import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Path of the bundled Noto Sans Devanagari licence (SIL OFL 1.1).
const String notoSansDevanagariLicenseAsset =
    'assets/fonts/noto_sans_devanagari/OFL.txt';

/// Adds the bundled fonts' licences to Flutter's licence registry, so they
/// appear on the licences page (`showLicensePage`) as the OFL requires the
/// licence to accompany the font.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(notoSansDevanagariLicenseAsset);
    yield LicenseEntryWithLineBreaks(['Noto Sans Devanagari'], text);
  });
}
