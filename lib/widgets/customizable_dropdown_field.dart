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
    return showDialog<String>(
      context: context,
      builder: (context) => _CustomOptionDialog(label: label, hint: hint),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mergedOptions = mergeUniqueOptions(builtInOptions, customOptions);
    final rawValue = value?.trim();
    final selectedValue = rawValue == null || rawValue.isEmpty
        ? null
        : rawValue;
    final selectedIsPresent =
        selectedValue == null ||
        mergedOptions.any(
          (option) => option.toLowerCase() == selectedValue.toLowerCase(),
        );
    final options = <String>[
      ...mergedOptions,
      if (!selectedIsPresent) selectedValue,
      addCustomDropdownOptionLabel,
    ];
    final safeValue = selectedValue == null
        ? null
        : options.firstWhere(
            (option) => option.toLowerCase() == selectedValue.toLowerCase(),
            orElse: () => selectedValue,
          );

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

class _CustomOptionDialog extends StatefulWidget {
  const _CustomOptionDialog({required this.label, this.hint});

  final String label;
  final String? hint;

  @override
  State<_CustomOptionDialog> createState() => _CustomOptionDialogState();
}

class _CustomOptionDialogState extends State<_CustomOptionDialog> {
  late final TextEditingController _controller;

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Add ${widget.label}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          style: FilledButton.styleFrom(textStyle: theme.textTheme.labelLarge),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
