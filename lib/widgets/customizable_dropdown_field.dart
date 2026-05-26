import 'package:flutter/material.dart';

import '../utils/dropdown_option_utils.dart';

class CustomizableDropdownField extends StatelessWidget {
  const CustomizableDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.builtInOptions,
    required this.customOptions,
    required this.onChanged,
    required this.onCustomValueSubmitted,
    this.enabled = true,
    this.validator,
    this.hint,
  });

  final String label;
  final String? value;
  final List<String> builtInOptions;
  final List<String> customOptions;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onCustomValueSubmitted;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final String? hint;

  Future<void> _handleChanged(BuildContext context, String? selected) async {
    if (selected != addCustomDropdownOptionLabel) {
      onChanged(selected);
      return;
    }

    final customValue = await _showCustomValueDialog(context);
    if (customValue == null) {
      return;
    }

    onCustomValueSubmitted(customValue);
    onChanged(customValue);
  }

  Future<String?> _showCustomValueDialog(BuildContext context) async {
    final controller = TextEditingController();

    try {
      return showDialog<String>(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);

          return AlertDialog(
            title: Text('Add $label'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: label, hintText: hint),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                final value = controller.text.trim();
                Navigator.of(context).pop(value.isEmpty ? null : value);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  Navigator.of(context).pop(value.isEmpty ? null : value);
                },
                style: FilledButton.styleFrom(
                  textStyle: theme.textTheme.labelLarge,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mergedOptions = mergeUniqueOptions(builtInOptions, customOptions);
    final options = [...mergedOptions, addCustomDropdownOptionLabel];
    final safeValue = options.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(labelText: label, hintText: hint),
      items: options
          .map(
            (option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(),
      onChanged: enabled
          ? (selected) => _handleChanged(context, selected)
          : null,
      validator: validator,
    );
  }
}
