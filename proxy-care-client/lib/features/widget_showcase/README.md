# features/widget_showcase

A development-only page, `/widget-showcase`, that shows every design-system
component in `lib/shared/widgets/` with its variants, sizes and states, so
they can be inspected and tried in a browser. It is not a product screen.

- `widget_showcase_routes.dart`: the route module. `isEnabled(env)` is true
  only when `FEATURE_FLAGS` contains `widget_showcase` and `APP_ENV` is not
  `production`; `enabledRouteModules` in `lib/app_routes.dart` registers the
  module only then. The route is public: it shows no user data and calls no
  API, so it does not depend on the authentication state.
- `presentation/widget_showcase_screen.dart`: category filter, local density
  preview (the app-wide density is not changed) and the sections.
- `presentation/sections/`: one file per category. Each uses only existing
  components and theme tokens; interactions keep in-memory state and
  confirm with the design system's snackbar.
- `presentation/widgets/showcase_layout.dart`: the showcase's own layout
  (section, specimen card, column, wrap, labelled switch). Specimens are at
  most one phone frame (`PcSizes.frame`) wide, three per row on desktop.

Showcase labels are English literals on purpose: the page is a development
tool and its text is not part of the app's translations.

When a component is added to `lib/shared/widgets/`, add it to the matching
section (or a new `ShowcaseCategory`).
