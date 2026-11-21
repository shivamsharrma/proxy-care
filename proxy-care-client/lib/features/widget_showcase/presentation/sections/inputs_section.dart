import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

/// `PcTextField` (states and input types) and `PcOtpInput`.
class InputsSection extends StatefulWidget {
  /// Creates the section.
  const InputsSection({super.key});

  @override
  State<InputsSection> createState() => _InputsSectionState();
}

class _InputsSectionState extends State<InputsSection> {
  final _filled = TextEditingController(text: 'Asha Verma');
  final _disabled = TextEditingController(text: 'Not editable');
  final _invalid = TextEditingController(text: '98765');
  final _mobile = TextEditingController();
  String? _mobileError;
  String _otp = '';

  @override
  void dispose() {
    _filled.dispose();
    _disabled.dispose();
    _invalid.dispose();
    _mobile.dispose();
    super.dispose();
  }

  void _validateMobile(String value) {
    setState(() {
      _mobileError = switch (value.length) {
        0 => 'Enter a mobile number',
        10 => null,
        _ => 'Enter all 10 digits',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShowcaseSection(
      title: 'Input fields',
      description:
          'PcTextField states and input types, and the 6-digit PcOtpInput. '
          'Tap a field to see its focused state. PcTextField has no '
          'read-only mode, so none is shown.',
      specimens: [
        ShowcaseSpecimen(
          label: 'PcTextField · states',
          child: ShowcaseColumn(
            children: [
              const PcTextField(label: 'Empty'),
              const PcTextField(
                label: 'Placeholder and helper',
                placeholder: 'e.g. City hospital',
                helper: 'Helper text sits under the field',
              ),
              const PcTextField(
                label: 'Required',
                placeholder: 'Full name',
                isRequired: true,
              ),
              PcTextField(label: 'Filled', controller: _filled),
              PcTextField(
                label: 'Disabled',
                controller: _disabled,
                enabled: false,
              ),
              PcTextField(
                label: 'Error',
                controller: _invalid,
                error: 'Enter a 10-digit mobile number',
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcTextField · live validation',
          note: 'Type to validate: required, digits only, exactly 10 digits.',
          child: PcTextField(
            label: 'Mobile number',
            controller: _mobile,
            isRequired: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            error: _mobileError,
            helper: 'We send the code to this number',
            onChanged: _validateMobile,
          ),
        ),
        const ShowcaseSpecimen(
          label: 'PcTextField · input types',
          child: ShowcaseColumn(
            children: [
              PcTextField(
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                placeholder: 'name@example.com',
              ),
              PcTextField(
                label: 'Number',
                keyboardType: TextInputType.number,
                placeholder: '0',
              ),
              PcTextField(label: 'Password', obscureText: true),
              PcTextField(
                label: 'Multiline',
                multiline: true,
                placeholder: 'Anything the caretaker should know',
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcOtpInput',
          note: 'Type 6 digits. Value: ${_otp.isEmpty ? '(empty)' : _otp}',
          child: PcOtpInput(
            onChanged: (value) => setState(() => _otp = value),
            onCompleted: (value) =>
                showShowcaseFeedback(context, 'Code $value entered'),
          ),
        ),
        const ShowcaseSpecimen(
          label: 'PcOtpInput · error',
          child: PcOtpInput(error: 'That code is not right. Try again.'),
        ),
      ],
    );
  }
}
