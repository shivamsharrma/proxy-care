/// Spacing scale from section 3 (4px base). `space-0.5` is [spaceHalf];
/// every other token keeps its number (`space-6` is [space6]).
abstract final class PcSpacing {
  /// `space-0.5`: 2.
  static const double spaceHalf = 2;

  /// `space-1`: 4.
  static const double space1 = 4;

  /// `space-2`: 8.
  static const double space2 = 8;

  /// `space-3`: 12.
  static const double space3 = 12;

  /// `space-4`: 16.
  static const double space4 = 16;

  /// `space-5`: 20.
  static const double space5 = 20;

  /// `space-6`: 24.
  static const double space6 = 24;

  /// `space-7`: 28.
  static const double space7 = 28;

  /// `space-8`: 32.
  static const double space8 = 32;

  /// `space-10`: 40.
  static const double space10 = 40;

  /// `space-12`: 48.
  static const double space12 = 48;

  /// Inset for free text: headings, paragraphs, section labels, step
  /// progress and the bottom action area (`space-6`).
  static const double textInset = space6;

  /// Inset for cards and list groups (`space-4`).
  static const double cardInset = space4;
}
