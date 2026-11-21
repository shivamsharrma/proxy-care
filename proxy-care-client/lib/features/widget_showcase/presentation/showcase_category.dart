/// The showcase's categories, in display order. Only categories with real
/// design-system components exist.
///
/// Labels are short because they are chip labels: a chip never wraps, so a
/// long label would overflow narrow windows or large text sizes. Each
/// section shows its full title.
enum ShowcaseCategory {
  /// `PcButton`, `PcIconButton`.
  buttons('Buttons'),

  /// `PcTextField`, `PcOtpInput`.
  inputs('Inputs'),

  /// `PcSwitch`, selection cards, checkbox tiles, chips, segmented button.
  selection('Selection'),

  /// `PcCard` and the card family.
  cards('Cards'),

  /// `PcListGroup` and its rows.
  lists('Lists'),

  /// `PcTopAppBar`, `PcNavigationBar`, `PcStepProgress`.
  navigation('Navigation'),

  /// `showPcDialog`, `showPcProgressSheet`.
  overlays('Dialogs'),

  /// Notes, banners, badges, tags, notifications, snackbar.
  feedback('Feedback'),

  /// Loading buttons and the progress sheet.
  loading('Loading'),

  /// `PcEmptyState`, `PcResultState`.
  emptyStates('Empty states'),

  /// `PcAvatar`.
  avatars('Avatars'),

  /// The type scale and the density text roles.
  typography('Typography'),

  /// The icons the components use, at the icon size tokens.
  icons('Icons'),

  /// Action area, constrained content, focus ring, window class.
  layout('Layout');

  const ShowcaseCategory(this.label);

  /// Visible name.
  final String label;
}
