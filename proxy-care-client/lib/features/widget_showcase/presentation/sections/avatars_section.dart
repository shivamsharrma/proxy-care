import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

/// `PcAvatar` in every size.
class AvatarsSection extends StatelessWidget {
  /// Creates the section.
  const AvatarsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowcaseSection(
      title: 'Avatars',
      description: 'Initials avatars, the only avatar style defined.',
      specimens: [
        ShowcaseSpecimen(
          label: 'PcAvatar · sizes',
          note: 'sm, md and lg, with their diameter in dp.',
          child: ShowcaseWrap(
            children: [
              for (final size in PcAvatarSize.values)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PcAvatar(
                      initials: 'AV',
                      size: size,
                      semanticLabel: 'Asha Verma',
                    ),
                    ShowcaseCaption('${size.name} · ${size.diameter.round()}'),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
