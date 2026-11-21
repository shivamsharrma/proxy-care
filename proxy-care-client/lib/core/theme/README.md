# core/theme

The Proxy Care Design System as Flutter theme infrastructure. The single
source of truth is `claude/proxycare-design-system.md`; token names mirror it.
`docs/design-system-mapping.md` maps every token and component to code and
lists the spec's ambiguities.

- `tokens/`: raw values. `PcPalette` (colors), `PcColors` (semantic roles and
  tones), `PcTypeScale` / `PcTextStyles` (type), `PcSpacing`, `PcRadii`,
  `PcBorders`, `PcStrokes`, `PcShadows`, `PcSizes`, `PcOpacity`.
- `app_density.dart`: the two densities (family = standard, caretaker =
  comfortable) and their sizes.
- `pc_theme.dart`: the `PcTheme` `ThemeExtension`; widgets read it with
  `context.pc`.
- `app_theme.dart`: `buildProxyCareTheme(density)` → `ThemeData`.
- `theme_providers.dart`: `appDensityProvider`, `appThemeProvider`,
  `appThemeModeProvider` (light only).
- `system_ui.dart`: status and navigation bar styling.
- `theme.dart`: imports everything above.

Rules: widgets never hard-code a color, size or text style; they use tokens.
To change a value, change the token, and only when the design system
changes.
