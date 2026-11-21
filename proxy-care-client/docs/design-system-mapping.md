# Design system → Flutter mapping

How `claude/proxycare-design-system.md` (the single source of truth) maps onto
the Flutter code. The Markdown's component table says "full specs on each
component page"; those pages (in the Design System artifact) supply component
dimensions and states. Where a page and the Markdown disagree, the Markdown
wins. Values the spec does not give are listed under
[Ambiguities](#ambiguities) with what the code does instead of inventing a
value.

Imports: `core/theme/theme.dart` (tokens and theme) and
`shared/widgets/design_system.dart` (components).

## Tokens

| Spec (section) | Flutter | File |
| --- | --- | --- |
| Color palette `color-*` (1) | `PcPalette.primary500` … (one constant per token) | `core/theme/tokens/pc_palette.dart` |
| Semantic aliases `color-bg`, `color-surface`, `color-text-muted`, … (1) | `PcColors` roles (`bg`, `surface`, `textMuted`, …), instance `PcColors.light` | `tokens/pc_colors.dart` |
| Semantic states (success / warning / error / info) and the tint rule (1) | `PcTone` + `PcToneColors(container, accent, onContainer)` | `tokens/pc_colors.dart` |
| Type tokens `display` … `code`, `c-*` (2) | `PcTypeScale.<token>` (`TextStyle`, exact size / line height / weight / tracking) | `tokens/pc_typography.dart` |
| Density-dependent text roles (2) | `PcTextStyles.standard` / `.comfortable` | `tokens/pc_typography.dart` |
| Families: Roboto, Noto Sans Devanagari (2) | MVP decision: platform default typeface (no family set) + bundled `PcFonts.devanagari` as `PcFonts.fallback` | `tokens/pc_typography.dart`, `assets/fonts/` |
| Breakpoints (not in the spec) | `PcBreakpoints.provisional`: compact < 600dp, expanded ≥ 600dp, max content 720dp; `context.pcWindowClass`, `PcConstrainedContent` | `tokens/pc_breakpoints.dart` |
| Spacing `space-0.5` … `space-12`, insets 24 / 16 (3) | `PcSpacing.spaceHalf`, `space1` … `space12`, `textInset`, `cardInset` | `tokens/pc_spacing.dart` |
| Frame, chrome and component sizes `size-*` (3, 5, 6) | `PcSizes` | `tokens/pc_sizes.dart` |
| Radii `radius-xs` … `radius-full` (4) | `PcRadii.xs`, `sm`, `md`, `lg`, `xl`, `xxl` (2xl), `xxxl` (3xl), `full` | `tokens/pc_shape.dart` |
| Borders `border-thin` / `border-thick` (4) | `PcBorders.thin` / `thick` | `tokens/pc_shape.dart` |
| Icon strokes 2 / 2.5 / 1.5 (5) | `PcStrokes.icon` / `check` / `illustration` | `tokens/pc_shape.dart` |
| Shadows `shadow-1..3` (4) | `PcShadows.shadow1..3` (`List<BoxShadow>`) | `tokens/pc_elevation.dart` |
| State layers 8% / 12%, disabled 38%, map opacities (component pages, 5) | `PcOpacity` | `tokens/pc_states.dart` |

## Theme

| Spec | Flutter |
| --- | --- |
| Light theme only | `buildProxyCareTheme(density)` → `ThemeData` (Material 3); `appThemeModeProvider` is fixed to `ThemeMode.light`; no `darkTheme` |
| Two densities: family (standard), caretaker (comfortable) | `AppDensity` + `PcDensityMetrics` (56/64 action, 56/60 input, 80/84 nav, 28/32 badge); switched at runtime with `appDensityProvider` (`AppDensityController.select`) and applied by `appThemeProvider` |
| Values `ThemeData` has no slot for | `PcTheme` `ThemeExtension` (colors, text roles, metrics); read with `context.pc` |
| Brand roles for framework widgets | `proxyCareColorScheme` (`ColorScheme`), `proxyCareTextTheme` (`TextTheme`: `display`→displaySmall, `h1`→headlineMedium, `h2`→headlineSmall, `h3`→titleLarge, `title-md`→titleMedium, `title-sm`→titleSmall, body roles→body*, `button-sm`→labelLarge, `badge`→labelMedium, `nav-label`→labelSmall) |
| Flat cards, no shadow tint | `surfaceTint` transparent; components draw borders, not elevation |
| State layers, no ripple | `splashFactory: NoSplash`; overlays from `pcStateLayer` |
| 48px minimum targets | `MaterialTapTargetSize.padded`, `VisualDensity.standard` on every platform |
| Scrim, sheets, snackbar, nav bar, dividers, progress | `bottomSheetTheme`, `snackBarTheme`, `navigationBarTheme`, `dividerTheme`, `progressIndicatorTheme` |
| Status bar on `color-bg` | `PcSystemUi.light` (transparent status bar, dark icons), applied by `PcTopAppBar` |

## Components

| Spec component (variants) | Flutter widget |
| --- | --- |
| Button: Filled, Tonal, Outlined, Text, Destructive filled / text; sizes 64 / 56 / 48 / 52 / 44 / 40; states hover, focus, pressed, disabled (+ reason caption), loading | `PcButton` (`PcButtonVariant`, `PcButtonSize`; `size: null` = density screen action) |
| Icon button: Standard, Filled, Tonal, On-map, Info (44) | `PcIconButton` (required `semanticLabel`) |
| Text field: outlined input, textarea; default / focus / filled / error / disabled | `PcTextField` (`multiline`) |
| OTP input: 6 cells, active, error | `PcOtpInput` |
| Chip: choice, time slot, language toggle | `PcChoiceChip` (`PcChipType`) |
| Segmented button | `PcSegmentedButton<T>` |
| Date cell | `PcDateCell` |
| Selection card: radio card (incl. urgent), checkbox tile | `PcSelectionCard`, `PcCheckboxTile` |
| Switch 52×32 | `PcSwitch` |
| Card: surface, stat tile, role card, attention, expandable, key–value summary | `PcCard` (`PcCardVariant`), `PcStatTile`, `PcRoleCard`, `PcExpandableCard`, `PcSummary` |
| Status card | `PcBanner.status` with a `trailing` control |
| List group: rows, dividers, icon wells, group header | `PcListGroup`, `PcListRow`, `PcIconWell`, `PcSectionLabel` |
| Badge: status (4 tones), tag, count | `PcStatusBadge`, `PcTag`, `PcCountBadge` |
| Banner: note, status banner (4 tones) | `PcBanner.note`, `PcBanner.status` |
| Notification: snackbar, heads-up, tooltip / info tip | `showPcSnackBar` + `PcSnackBarContent`, `PcHeadsUpNotification`, `PcInfoTip` |
| Dialog: alert / confirm (destructive) | `PcDialog`, `showPcDialog` |
| Bottom sheet: modal progress sheet | `PcProgressSheet`, `showPcProgressSheet` |
| Top app bar: back, close (and none for tab roots) | `PcTopAppBar` (`PcAppBarLeading`) |
| Navigation bar: 4 tabs, 80 / 84 | `PcNavigationBar` (styled by the theme) |
| Step progress: segmented flow steps | `PcStepProgress` |
| Avatar: initials 36 / 44 / 48 | `PcAvatar` (`PcAvatarSize`) |
| Empty & result state | `PcEmptyState` (+ `PcDashedBorderPainter`), `PcResultState` |
| Bottom action area (layout) | `PcBottomActionArea` |
| Focus ring (recommended state) | `PcFocusRing`, used by every focusable component |
| Icons (section 5) | Flutter's built-in Material icons (`Icons.check`, `Icons.arrow_back`, `Icons.close`, `Icons.chevron_right`, `Icons.expand_more`, `Icons.error_outline`) |

### Not implemented in this milestone

These are documented but tied to features that do not exist yet, or need a
dependency or decision first:

- **Maps:** the map marker avatar, persistent map sheet, flat vector map,
  route styling and "Live" indicator. They need a map package.
- **Visit tracker and time bar** (StepProgress page). They are visit-domain
  displays; they will be built with the visits feature on top of the same
  tokens.
- **Select field** (TextField page: 12px side padding). It needs a decision on
  the picker (Material `DropdownMenu` vs a bottom-sheet list), which the spec
  does not show.
- **Checklist row** (ListGroup page: 24px native checkbox). Material's checkbox
  is 18px; matching 24px needs a custom checkbox, deferred to the checklist
  feature.
- **Top app bar greeting block and earnings pill.** They are tab-root content
  for the Home and Earnings features.
- **Caretaker profile photo frame** (96×120 dashed placeholder). It needs the
  camera / upload flow.
- **Search / loading illustration** (concentric circles). It belongs to the
  matching screen.
- **Custom icon set.** The spec describes a custom outline set; the MVP
  decision is Flutter's built-in Material icons.

## Ambiguities

Each is a place where the spec is silent or contradicts itself. The code does
what the right-hand column says, and nothing else is assumed.

| # | Spec | Ambiguity | What the code does |
| --- | --- | --- | --- |
| A1 | "Light theme only (no dark theme exists in the designs)" | Dark theme, system theme and a user theme preference are not specified | Only the light theme exists. `ThemeMode.light` comes from a provider, so a dark theme can be added without touching the app widget. Nothing is persisted (there is no preference to persist). |
| A2 | Responsive breakpoints | None given. The frame is 390px, single column. | MVP decision, provisional: compact below 600dp, adaptive tablet layout from 600dp, 720dp maximum width for constrained content surfaces only (`PcBreakpoints`, configurable through `PcTheme.layout`). |
| A3 | Fonts: "Roboto (Google Fonts)", Noto Sans Devanagari | The font files are not supplied | MVP decision: the platform's native typeface for Latin text (no family set); Noto Sans Devanagari v2.007 bundled as static 400 / 500 / 700 instances (SIL OFL 1.1, licence in `assets/fonts/` and registered with `LicenseRegistry`). |
| A4 | Icons: "custom outline set" | The set is not supplied | MVP decision: Flutter's built-in Material icons, sized by the spec's 18 / 20 / 24 icon tokens. Material icons are filled glyphs, so the spec's stroke widths (2, check 2.5) do not apply. |
| A5 | No `color-secondary-500` exists | Material's `ColorScheme.secondary` needs a value | `secondary` = `color-primary-500`; `secondaryContainer` = `color-secondary-100`. |
| A6 | Info tone accent is "—" | Icons in info notes need a color | Icons use the on-color `color-info-900` ("icon color follows the text"). |
| A7 | Badge page: comfortable label "15", no line height | Line height missing | Keeps the `badge` token's 16px line height. |
| A8 | BottomSheet page: title "20/28 500" | Not a named type token | Added as `PcTypeScale.sheetTitle` with that exact value. Body "15/22" uses `c-body-md`. |
| A9 | Badge page: "padding 0 10 0 8, gap 6" | Off the 4px scale; decision #18 says off-grid *gaps* map to the scale | Kept as specified for this component (`_badgeEndPadding` 10, `_badgeGap` 6), since the component page is more specific. |
| A10 | Snackbar "padding 14 16", heads-up "padding 12 14" | 14 is off-grid; decision #18 maps 14 → 16 | Uses 16 (snackbar 16 / 16, heads-up 12 / 16). |
| A11 | Note "gap 10–12", icon "18–20px" | A range | 12 and 20 (`size-icon-md`, which section 5 assigns to notes). |
| A12 | Switch off thumb "16–20px" | A range | 16. The 4px inner padding is measured inside the 2px off border. |
| A13 | Check mark stroke "2.5–3" | A range | Not applicable with Material icons (A4). |
| A14 | Section 7: 48px minimum targets; Chip page: 32px chips wrapping 8px apart | 32px chips are below 48px | Chips keep the specified 32 / 36px size and 8px wrap gap. Flutter's padded targets apply to buttons (40 / 44px buttons get a 48px target). |
| A15 | Button page: disabled caption "under the button" | Gap and alignment missing | 8px gap (`space-2`), centered, `body-sm` muted. |
| A16 | Button page: loading spinner 20px | Stroke width missing | 2px (`PcStrokes.icon`), in the label color. |
| A17 | Chip page: language toggle "tonal + check" | Selected padding missing | Same rule as choice chips: 8px before the check. |
| A18 | Chip page: date cell 60×76 | Weekday and day text styles missing | Weekday `body-sm`, day number `amount-md` (`tokens.json` lists the date-cell day number under `amount-md`), both in the cell's text color. |
| A19 | SelectionCard page: checkbox tile | Unselected icon-tile fill, tile layout and badge position missing | Fill `color-secondary-100` (section 1 assigns it to icon wells), urgent `color-error-100`. Icon tile above the title, 12px apart. Check badge at the top-right inside the 12px padding; the check inside is 16px (badge minus its 2px ring). |
| A20 | SelectionCard page: urgent radio | Radio ring color when urgent and selected missing | Uses the error accent, like the border. |
| A21 | Card page: key–value total | Total label style missing | `title-sm` (the expandable summary's 16 / 500). |
| A22 | Card page: expandable `<details>` | Disclosure marker missing | A 20px muted chevron that flips when open. |
| A23 | Badge page: tag "12/500" | Line height and colors missing | 12 / 16 / 500 (`overline` metrics without tracking). Colors come from a tone, neutral by default. |
| A24 | Badge page: count badge "white 12px" | Weight missing | 500. |
| A25 | Dialog page: icon disc | Non-destructive disc colors and icon size missing; body alignment missing | `color-secondary-100` / `color-secondary-900` and a 20px icon (40px wells use `size-icon-md`). The body is centered like the title. |
| A26 | BottomSheet page: progress sheet | Gaps between spinner, title and body missing | 24 (`space-6`) and 8 (the "intro 8px below" rhythm). |
| A27 | EmptyState page: result | Gaps and top padding "40–48" | Top 40 (`space-10`). Disc → title 24, title → body 8, body → action 32 (`space-8`, "feature list to CTA spacing"). |
| A28 | EmptyState page: dashed border | Dash length missing | 4px dashes with 4px gaps (`space-1`). |
| A29 | TopAppBar page: "Tab roots show the title as an `h1` with 24px inset" vs. section 2: `h3` is the "tab page title" | Contradiction | `PcTopAppBar` always uses `h3`. With `leading: none` the title gets the 24px inset (4 + 20). An `h1` tab-root heading is screen content. |
| A30 | OtpInput page: error message style | Text style missing | `body-md` in `color-error-500`. |
| A31 | Avatar page: initials 14 / 16 / 18 | Line height missing | Single-line, line height 1, centered. |
| A32 | Navigation bar labels | Inactive label color not stated | `color-text-muted` ("icon color follows the text": muted when inactive), active `color-text`. |
| A33 | System navigation bar (Android) | Not specified | Only the icon brightness is set (dark); the color is left to the platform. |
| A34 | Motion | No durations or curves in the spec | Components change state without custom animations (framework defaults only). |
| A35 | "Still open" items in the Decisions log (badge wrap on H-CArrive, C-Review button order, 22px call icons, large pickup code) | Open design calls | Not encoded: they are screen-level. `PcIconButton` always uses the specified 24px icon. |
| A36 | Section 4: "When a border goes 1px → 2px on select/focus, padding drops by 1px so content doesn't shift" | This is CSS's box model (border outside the padding). Flutter shapes paint their border inside the box. | Card and selection-card padding is the spec padding plus the 1px base border, at every border width. Content sits exactly where the CSS puts it and never moves. |
