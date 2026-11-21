import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/tokens/pc_spacing.dart';
import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

const _radioOptions = ['Morning visit', 'Afternoon visit', 'Evening visit'];
const _timeOfDay = ['Morning', 'Afternoon', 'Evening'];
const _timeSlots = ['9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM'];
const _languages = ['English', 'हिन्दी'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu'];
const _days = ['17', '18', '19', '20'];
const _checkboxIcons = [
  Icons.directions_car_outlined,
  Icons.local_pharmacy_outlined,
  Icons.receipt_long_outlined,
  Icons.accessible,
];
const _checkboxTitles = ['Pickup', 'Pharmacy', 'Bills', 'Wheelchair'];

/// `PcSwitch`, `PcSelectionCard`, `PcCheckboxTile`, `PcChoiceChip`,
/// `PcDateCell` and `PcSegmentedButton`.
class SelectionSection extends StatefulWidget {
  /// Creates the section.
  const SelectionSection({super.key});

  @override
  State<SelectionSection> createState() => _SelectionSectionState();
}

class _SelectionSectionState extends State<SelectionSection> {
  bool _switchOn = true;
  int _radio = 0;
  final Set<int> _checked = {0};
  String _timeOfDayChoice = _timeOfDay.first;
  String? _slot;
  final Set<String> _languageChoice = {_languages.first};
  int _day = 0;
  int _segment = 0;

  void _toggle<T>(Set<T> set, T value) {
    setState(() {
      if (!set.remove(value)) set.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShowcaseSection(
      title: 'Selection controls',
      description:
          'The design system has no plain checkbox, radio button or '
          'dropdown. Single choice uses selection cards, chips, date cells '
          'and the segmented button; multiple choice uses checkbox tiles and '
          'toggle chips.',
      specimens: [
        ShowcaseSpecimen(
          label: 'PcSwitch',
          child: ShowcaseColumn(
            children: [
              ShowcaseToggle(
                label: _switchOn ? 'On' : 'Off',
                value: _switchOn,
                onChanged: (value) => setState(() => _switchOn = value),
              ),
              const ShowcaseToggle(
                label: 'Disabled, on',
                value: true,
                onChanged: null,
              ),
              const ShowcaseToggle(
                label: 'Disabled, off',
                value: false,
                onChanged: null,
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcSelectionCard · single choice',
          note: 'Selected: ${_radioLabel(_radio)}',
          child: ShowcaseColumn(
            children: [
              for (var i = 0; i < _radioOptions.length; i++)
                PcSelectionCard(
                  title: _radioOptions[i],
                  meta: i == 0 ? 'With a leading avatar' : null,
                  leading: i == 0
                      ? const PcAvatar(initials: 'MK', size: PcAvatarSize.sm)
                      : null,
                  selected: _radio == i,
                  onTap: () => setState(() => _radio = i),
                ),
              PcSelectionCard(
                title: 'Urgent',
                meta: 'Error tone when selected',
                urgent: true,
                selected: _radio == _radioOptions.length,
                onTap: () => setState(() => _radio = _radioOptions.length),
              ),
              const PcSelectionCard(
                title: 'Unavailable',
                meta: 'Disabled (no onTap)',
                selected: false,
                onTap: null,
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcCheckboxTile · multiple choice',
          note: 'Selected: ${_checked.length}. The last tile is urgent.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < _checkboxTitles.length; row += 2) ...[
                if (row > 0) const SizedBox(height: PcSpacing.space3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _checkboxTile(row)),
                    const SizedBox(width: PcSpacing.space3),
                    Expanded(child: _checkboxTile(row + 1)),
                  ],
                ),
              ],
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcChoiceChip · types',
          note:
              'Choice and time slot chips are single choice; language '
              'chips toggle independently.',
          child: ShowcaseColumn(
            stretch: false,
            children: [
              ShowcaseWrap(
                children: [
                  for (final label in _timeOfDay)
                    PcChoiceChip(
                      label: label,
                      selected: _timeOfDayChoice == label,
                      onTap: () => setState(() => _timeOfDayChoice = label),
                    ),
                  const PcChoiceChip(
                    label: 'Disabled',
                    selected: false,
                    onTap: null,
                  ),
                ],
              ),
              ShowcaseWrap(
                children: [
                  for (final slot in _timeSlots)
                    PcChoiceChip(
                      label: slot,
                      type: PcChipType.timeSlot,
                      selected: _slot == slot,
                      onTap: () => setState(() => _slot = slot),
                    ),
                ],
              ),
              ShowcaseWrap(
                children: [
                  for (final language in _languages)
                    PcChoiceChip(
                      label: language,
                      type: PcChipType.language,
                      inGroup: false,
                      selected: _languageChoice.contains(language),
                      onTap: () => _toggle(_languageChoice, language),
                    ),
                ],
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcDateCell',
          note: 'Selected: ${_weekdays[_day]} ${_days[_day]}',
          child: ShowcaseWrap(
            children: [
              for (var i = 0; i < _days.length; i++)
                PcDateCell(
                  weekday: _weekdays[i],
                  day: _days[i],
                  selected: _day == i,
                  onTap: () => setState(() => _day = i),
                ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcSegmentedButton',
          note: 'Selected segment: ${_segment + 1}',
          child: PcSegmentedButton<int>(
            segments: const [
              PcSegment(value: 0, label: 'Upcoming'),
              PcSegment(value: 1, label: 'Past'),
              PcSegment(value: 2, label: 'All'),
            ],
            selected: _segment,
            onChanged: (value) => setState(() => _segment = value),
          ),
        ),
      ],
    );
  }

  Widget _checkboxTile(int index) {
    return PcCheckboxTile(
      icon: Icon(_checkboxIcons[index]),
      title: _checkboxTitles[index],
      meta: 'Option ${index + 1}',
      urgent: index == _checkboxTitles.length - 1,
      selected: _checked.contains(index),
      onTap: () => _toggle(_checked, index),
    );
  }

  static String _radioLabel(int index) =>
      index < _radioOptions.length ? _radioOptions[index] : 'Urgent';
}
