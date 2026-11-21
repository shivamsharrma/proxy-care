import 'package:material_ui/material_ui.dart';

/// A destination in a [PcNavigationBar].
final class PcNavDestination {
  /// Creates a destination.
  const PcNavDestination({required this.icon, required this.label});

  /// 24px outline icon.
  final Widget icon;

  /// Tab name ("Home", "Visits", "Payments", "Family").
  final String label;
}

/// Bottom navigation with four destinations, shown only on tab roots
/// (NavigationBar page).
///
/// Height 80 (84 caretaker) on `color-surface-container`; the active item
/// sits in a 64×32 `color-secondary-100` pill with its label at weight 700.
/// Sizes, colors and label styles come from the theme built by
/// `buildProxyCareTheme`, so this only adapts the destinations.
class PcNavigationBar extends StatelessWidget {
  /// Creates a navigation bar.
  const PcNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// The tabs, left to right.
  final List<PcNavDestination> destinations;

  /// Index of the current tab.
  final int selectedIndex;

  /// Called with the tapped tab's index.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: destination.icon,
            label: destination.label,
          ),
      ],
    );
  }
}
