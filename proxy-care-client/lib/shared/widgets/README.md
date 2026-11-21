# shared/widgets

The Proxy Care Design System components (buttons, fields, chips, cards,
lists, badges, banners, notifications, dialogs, sheets, app bar, navigation
bar, progress, avatars, empty and result states). Import
`design_system.dart`.

- Each widget follows its component page in the design system; see
  `docs/design-system-mapping.md` for the mapping and the decisions taken
  where the spec is silent.
- Styling comes only from `core/theme` tokens via `context.pc`.
- Stateless where possible; data in through constructor parameters.
- No providers, repositories or feature knowledge; no screens.
- Every control exposes semantics (role, state, label) and keeps a 48px
  target where the spec allows.
