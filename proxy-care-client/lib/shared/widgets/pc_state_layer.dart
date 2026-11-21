import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens/pc_states.dart';

/// Hover (8%) and pressed (12%) state layers of [color], the content color
/// of the control (its label or icon).
WidgetStateProperty<Color?> pcStateLayer(Color color) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return color.withValues(alpha: PcOpacity.pressed);
    }
    if (states.contains(WidgetState.hovered)) {
      return color.withValues(alpha: PcOpacity.hover);
    }
    return null;
  });
}
