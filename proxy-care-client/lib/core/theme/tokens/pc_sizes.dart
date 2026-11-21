/// Fixed sizes from sections 3–6 and the component pages. `size-*` tokens
/// keep their names; component dimensions are grouped by component.
abstract final class PcSizes {
  // Frame and chrome (section 3).

  /// `size-frame`: design frame width.
  static const double frame = 390;

  /// `size-app-bar`.
  static const double appBar = 64;

  /// `size-nav-bar`, family app.
  static const double navBar = 80;

  /// `size-nav-bar`, caretaker app.
  static const double navBarComfortable = 84;

  /// `size-touch`: minimum touch target.
  static const double touch = 48;

  // Buttons (Button page).

  /// `size-button-xl`: caretaker screen primary.
  static const double buttonXl = 64;

  /// `size-button-lg`: family screen primary; input height.
  static const double buttonLg = 56;

  /// `size-button-md`: dialog actions, text button under a primary.
  static const double buttonMd = 48;

  /// Larger button inside a card.
  static const double buttonCardLg = 52;

  /// Smaller button inside a card.
  static const double buttonCardSm = 44;

  /// `size-button-sm`: inline text buttons.
  static const double buttonSm = 40;

  /// Icon button.
  static const double iconButton = 48;

  /// Compact (info) icon button.
  static const double iconButtonCompact = 44;

  // Inputs.

  /// Text field height, comfortable density (standard is [buttonLg]).
  static const double inputComfortable = 60;

  /// OTP cell height.
  static const double otpCell = 56;

  // Chips and selection.

  /// `size-chip`: choice chip, language toggle.
  static const double chip = 32;

  /// Time-slot chip.
  static const double timeSlotChip = 36;

  /// Segmented button.
  static const double segmented = 48;

  /// Date cell width.
  static const double dateCellWidth = 60;

  /// Date cell height.
  static const double dateCellHeight = 76;

  /// Minimum selection-card height.
  static const double selectionCardMin = 56;

  /// Custom radio indicator.
  static const double radio = 20;

  /// Dot inside a selected radio.
  static const double radioDot = 10;

  /// Check badge on a selected checkbox tile.
  static const double checkBadge = 20;

  // Switch.

  /// Switch track width.
  static const double switchWidth = 52;

  /// Switch track height.
  static const double switchHeight = 32;

  /// Inner padding of the switch track.
  static const double switchPadding = 4;

  /// Thumb when on.
  static const double switchThumbOn = 24;

  /// Thumb when off (the page allows 16–20; the lower bound is used).
  static const double switchThumbOff = 16;

  /// Check inside the "on" thumb.
  static const double switchCheck = 16;

  // Lists and badges.

  /// List row minimum height.
  static const double listRow = 64;

  /// Checklist row minimum height.
  static const double checklistRow = 56;

  /// `size-badge`: status badge, family app.
  static const double badge = 28;

  /// Status badge, caretaker app.
  static const double badgeComfortable = 32;

  /// Tag height.
  static const double tag = 24;

  /// Count badge height and minimum width.
  static const double countBadge = 20;

  /// Status dot in a badge.
  static const double statusDot = 8;

  // Icons (section 5).

  /// `size-icon-sm`: in buttons ≤ 48px, chips.
  static const double iconSm = 18;

  /// `size-icon-md`: in 40px wells, list rows, notes, 56px buttons.
  static const double iconMd = 20;

  /// `size-icon-lg`: app bar, nav, icon buttons, banners.
  static const double iconLg = 24;

  /// Empty-state hero icon.
  static const double iconEmptyState = 32;

  /// Icon in a 72px result disc.
  static const double iconResultSm = 36;

  /// Icon in an 80px result disc.
  static const double iconResultLg = 44;

  /// Icon well: list leading circle, feature and purpose tiles.
  static const double iconWell = 40;

  /// Banner icon disc.
  static const double bannerDisc = 44;

  /// Dialog icon disc.
  static const double dialogDisc = 40;

  /// Heads-up notification icon disc.
  static const double headsUpDisc = 36;

  /// Info tip close button.
  static const double infoTipClose = 40;

  /// Result disc, smaller variant.
  static const double resultDiscSm = 72;

  /// Result disc, larger variant.
  static const double resultDiscLg = 80;

  // Avatars.

  /// `size-avatar-sm`.
  static const double avatarSm = 36;

  /// `size-avatar-md`.
  static const double avatarMd = 44;

  /// `size-avatar-lg`.
  static const double avatarLg = 48;

  // Navigation and progress.

  /// Active destination pill width.
  static const double navIndicatorWidth = 64;

  /// Active destination pill height.
  static const double navIndicatorHeight = 32;

  /// Flow step segment height.
  static const double stepBar = 4;

  /// Spinner in the modal progress sheet.
  static const double spinner = 48;

  /// Spinner ring width.
  static const double spinnerStroke = 5;
}
